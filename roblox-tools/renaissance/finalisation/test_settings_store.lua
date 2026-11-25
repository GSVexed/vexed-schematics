local Store = dofile((arg[1] or '.') .. '/settings_store.lua')
local function clone(v)
    if type(v) ~= 'table' then return v end
    local out = {}; for k, x in pairs(v) do out[k] = clone(x) end; return out
end
local function normal(v)
    return {schema=15, enabled=v and v.enabled == true or false, tab=v and v.tab == 'Vision' and 'Vision' or 'Survival'}
end
local function valid(v)
    return type(v.enabled)=='boolean' and (v.tab=='Vision' or v.tab=='Survival')
end
local store = Store.new(15, {primary='p', backup='b', legacy='l', validateLegacy=function(v) return v.schema==14 and type(v.enabled)=='boolean' end}, normal, valid)
local function fixture(data, fault)
    local io = {read=function(p) return clone(data[p]) end, write=function(p,v)
        if fault then local action=fault(p); if action=='fail' then return false elseif action=='corrupt' then data[p]={}; return true end end
        data[p]=clone(v); return true
    end}
    return io
end
local function run(name, f) f(); print('PASS '..name) end
local off, on=normal(nil),normal({enabled=true,tab='Vision'})
run('valid primary',function() local v,s=store.load(fixture({p=on,b=off})); assert(v.enabled and s=='loaded') end)
run('empty primary recovers backup',function() local v,s=store.load(fixture({p={},b=on})); assert(v.enabled and s=='recovered backup') end)
run('wrong schema recovers backup',function() local v,s=store.load(fixture({p={schema=16,enabled=false,tab='Vision'},b=on})); assert(v.enabled and s=='recovered backup') end)
run('missing field recovers backup',function() local v,s=store.load(fixture({p={schema=15,enabled=false},b=on})); assert(v.enabled and s=='recovered backup') end)
run('legacy migration',function() local v,s=store.load(fixture({l={schema=14,enabled=true}})); assert(v.enabled and s=='migrated') end)
run('invalid legacy defaults',function() local v,s=store.load(fixture({l={schema=14}})); assert(not v.enabled and s=='defaults') end)
run('false persists with valid backup',function() local d={p=on}; assert(store.save(fixture(d),off)); assert(d.p.enabled==false and d.b.enabled==true) end)
run('corrupt primary preserves backup',function() local d={p={},b=on}; assert(store.save(fixture(d),off)); assert(d.b.enabled==true and d.p.enabled==false) end)
run('backup failure stops primary write',function() local d={p=on}; assert(not store.save(fixture(d,function(p) if p=='b' then return 'fail' end end),off)); assert(d.p.enabled==true) end)
run('backup readback failure stops primary write',function() local d={p=on}; assert(not store.save(fixture(d,function(p) if p=='b' then return 'corrupt' end end),off)); assert(d.p.enabled==true) end)
run('primary write failure retains backup',function() local d={p=on}; assert(not store.save(fixture(d,function(p) if p=='p' then return 'fail' end end),off)); assert(d.b.enabled==true) end)
run('primary corruption recovers prior settings',function() local d={p=on}; local io=fixture(d,function(p) if p=='p' then return 'corrupt' end end); assert(not store.save(io,off)); local v,s=store.load(io); assert(v.enabled and s=='recovered backup') end)
print('12/12 passed')
