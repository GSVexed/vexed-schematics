// FERAL local input remap. No driver, networking, process injection or input recording.
// Only captures an un-injected physical primary button edge while one Roblox
// window is foreground AND a fresh, scoped hub heartbeat permits the remap.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;

static class Program {
    [STAThread] static int Main(string[] args) {
        if (args.Length == 1 && args[0] == "--self-test") {
            if (Marshal.SizeOf(typeof(Input)) != (IntPtr.Size==8 ? 40 : 28)) return 2;
            if (HoldRecovery.ReadyStable(100,279) || !HoldRecovery.ReadyStable(100,280)) return 5;
            if (HoldRecovery.ReadyStable(-1,999)) return 6;
            try { HoldState.SelfTest(); } catch { return 7; }
            return 0;
        }
        if (args.Length != 1 || !Directory.Exists(args[0])) return 2;
        bool owner;
        using (var mutex = new System.Threading.Mutex(true, @"Local\FERALLeftHoldBridgeV1", out owner)) {
            if (!owner) return 3;
            Application.EnableVisualStyles();
            try { using (var app = new Remapper(args[0])) { Application.Run(app); } return 0; }
            catch { try { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"status.txt"),"FAILED"); } catch {} return 4; }
        }
    }
    [StructLayout(LayoutKind.Sequential)] internal struct MouseInput {
        public int dx,dy; public uint mouseData,flags,time; public UIntPtr extra;
    }
    [StructLayout(LayoutKind.Sequential)] internal struct Input { public uint type; public MouseInput mouse; }
    [StructLayout(LayoutKind.Sequential)] internal struct Point { public int x,y; }
    [StructLayout(LayoutKind.Sequential)] internal struct HookData {
        public Point pt; public uint mouseData,flags,time; public UIntPtr extra;
    }
    internal delegate IntPtr MouseHook(int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll", SetLastError=true)] internal static extern IntPtr SetWindowsHookEx(int id,MouseHook proc,IntPtr module,uint thread);
    [DllImport("user32.dll")] internal static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] internal static extern IntPtr CallNextHookEx(IntPtr h,int code,IntPtr message,IntPtr data);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] internal static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll", SetLastError=true)] internal static extern uint SendInput(uint count,Input[] inputs,int size);
    [DllImport("user32.dll",SetLastError=true)] internal static extern bool RegisterHotKey(IntPtr hwnd,int id,uint modifiers,uint key);
    [DllImport("user32.dll")] internal static extern bool UnregisterHotKey(IntPtr hwnd,int id);
    internal static Input Edge(uint flags) { return new Input { type=0, mouse=new MouseInput { flags=flags } }; }
}
// Pure timing gate: never resume a captured press on the first readiness sample.
static class HoldRecovery {
    public static bool ReadyStable(long since, long now) {
        return since>=0 && now>=since && now-since>=180;
    }
}
// The actual hook/timer use this deterministic state machine. No OS calls here.
sealed class HoldState {
    public bool Captured, Repeating, Cancelled, Paused;
    long downAt, resumeAt=-1;
    public bool Held { get { return Captured && Repeating && !Cancelled && !Paused; } }
    public bool Tap { get { return Captured && !Repeating && !Cancelled && !Paused; } }
    public void Begin(long now) {
        Captured=true;Repeating=false;Cancelled=false;Paused=false;downAt=now;resumeAt=-1;
    }
    public void Revoke() { Cancelled=Captured;Repeating=false;Paused=false;resumeAt=-1; }
    public void End() { Captured=false;Repeating=false;Cancelled=false;Paused=false;resumeAt=-1; }
    public void Step(long now,bool enabled,bool sameWindow,bool sameToken,bool armed) {
        if(!Captured) return;
        if(!enabled || !sameWindow || !sameToken) { Revoke();return; }
        if(Cancelled) return;
        if(!armed) { Paused=true;Repeating=false;resumeAt=-1;return; }
        if(Paused) {
            if(resumeAt<0) resumeAt=now;
            if(HoldRecovery.ReadyStable(resumeAt,now)) { Paused=false;Repeating=true;resumeAt=-1; }
        }
        if(!Paused && !Repeating && now-downAt>=180) Repeating=true;
    }
    static void Check(bool ok) { if(!ok) throw new InvalidOperationException("Hold state regression"); }
    public static void SelfTest() {
        var h=new HoldState();
        h.Begin(0);h.Step(179,true,true,true,true);Check(h.Tap && !h.Held);
        h.End();Check(!h.Captured && !h.Held && !h.Tap);
        h.Begin(0);h.Step(180,true,true,true,true);Check(h.Held && !h.Tap);
        h.Step(181,true,true,true,false);Check(h.Paused && !h.Held && !h.Tap);
        h.Step(300,true,true,true,true);h.Step(479,true,true,true,true);Check(!h.Held);
        h.Step(480,true,true,true,true);Check(h.Held);
        for(int boundary=0;boundary<3;boundary++) {
            h.Begin(0);h.Step(180,true,true,true,true);Check(h.Held);
            h.Step(181,boundary!=0,boundary!=1,boundary!=2,true);Check(!h.Held);
            h.Step(10000,true,true,true,true);Check(h.Cancelled && !h.Held && !h.Tap);
            h.End();h.Begin(10001);h.Step(10181,true,true,true,true);Check(h.Held);
        }
        h.End();h.Step(999999,true,true,true,true);Check(!h.Held);
        // A release during a pause cannot produce a late tap or resume.
        h.Begin(0);h.Step(50,true,true,true,false);Check(!h.Tap);h.End();
        h.Step(500,true,true,true,true);Check(!h.Held && !h.Tap);
        // Long sessions with thousands of heartbeat gaps and transitions.
        for(int i=0;i<10000;i++) {
            long t=(long)i*1000;
            h.Begin(t);h.Step(t+180,true,true,true,true);Check(h.Held);
            h.Step(t+200,true,true,true,false);Check(!h.Held);
            h.Step(t+300,true,true,true,true);h.Step(t+480,true,true,true,true);Check(h.Held);
            h.End();Check(!h.Held);
        }
    }
}
sealed class HotkeyWindow : NativeWindow, IDisposable {
    readonly Action toggle;
    readonly bool registered;
    public HotkeyWindow(Action action) {
        toggle=action; CreateHandle(new CreateParams());
        registered=Program.RegisterHotKey(Handle,1,0x4003,0x7B); // Ctrl+Alt+F12, no repeat
    }
    protected override void WndProc(ref Message m) {
        if(m.Msg==0x0312 && m.WParam.ToInt32()==1) toggle();
        else base.WndProc(ref m);
    }
    public void Dispose() {
        if(registered) Program.UnregisterHotKey(Handle,1);
        DestroyHandle();
    }
}
sealed class Remapper : ApplicationContext {
    const string ReadySchema="FERAL_LEFT_HOLD_READY_V1", IntentSchema="FERAL_LEFT_HOLD_INTENT_V1";
    const int Down=0x0201, Up=0x0202, HoldMs=180;
    readonly string readyPath,intentPath,statusPath;
    readonly JavaScriptSerializer json=new JavaScriptSerializer();
    readonly Timer timer=new Timer();
    readonly Stopwatch clock=Stopwatch.StartNew();
    readonly NotifyIcon tray;
    readonly HotkeyWindow hotkey;
    readonly Program.MouseHook callback;
    IntPtr hook, cachedWindow, allowedWindow, captureWindow;
    uint cachedPid;
    bool cachedRoblox,enabled=true,allowed,disposed;
    readonly HoldState hold=new HoldState();
    readonly string instance=Guid.NewGuid().ToString("N");
    string token="", captureToken="";
    long seq,lastWrite=-1000;
    bool previousHeld;
    sealed class Tap { public IntPtr Window; public string Token; public long At; }
    readonly Queue<Tap> taps=new Queue<Tap>();
    public Remapper(string workspace) {
        readyPath=Path.Combine(workspace,ReadySchema+".json");
        intentPath=Path.Combine(workspace,IntentSchema+".json");
        statusPath=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"status.txt");
        var menu=new ContextMenuStrip();
        menu.Items.Add("Pause / resume (Ctrl+Alt+F12)",null,delegate { Toggle(); });
        menu.Items.Add("Exit FERAL input helper",null,delegate { ExitThread(); });
        tray=new NotifyIcon { Icon=SystemIcons.Application,Text="FERAL input helper - waiting for hub",Visible=true,ContextMenuStrip=menu };
        hotkey=new HotkeyWindow(Toggle);
        callback=OnMouse;
        hook=Program.SetWindowsHookEx(14,callback,Program.GetModuleHandle(null),0);
        if(hook==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        timer.Interval=20;
        timer.Tick+=delegate { Tick(); };
        timer.Start();
        File.WriteAllText(statusPath,"RUNNING");
    }
    bool RobloxForeground(IntPtr hwnd) {
        if(hwnd==IntPtr.Zero) return false;
        uint pid;Program.GetWindowThreadProcessId(hwnd,out pid);
        if(hwnd==cachedWindow && pid==cachedPid) return cachedRoblox;
        cachedWindow=hwnd;cachedPid=pid;cachedRoblox=false;
        try { using(var p=Process.GetProcessById((int)pid)) cachedRoblox=String.Equals(p.ProcessName,"RobloxPlayerBeta",StringComparison.OrdinalIgnoreCase); } catch {}
        return cachedRoblox;
    }
    bool ReadHeartbeat(out string nextToken) {
        nextToken="";
        try {
            var info=new FileInfo(readyPath);
            if(!info.Exists || info.Length<20 || info.Length>4096) return false;
            double age=(DateTime.UtcNow-info.LastWriteTimeUtc).TotalMilliseconds;
            if(age< -100 || age>650) return false;
            var data=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(readyPath));
            object schema,t,arm;
            if(data==null || !data.TryGetValue("schema",out schema) || (string)schema!=ReadySchema ||
                !data.TryGetValue("token",out t) || !(t is string) ||
                !Regex.IsMatch((string)t,@"^[A-Za-z0-9_]{1,128}$")) return false;
            nextToken=(string)t;
            return data.TryGetValue("armed",out arm) && arm is bool && (bool)arm;
        } catch { return false; }
    }
    bool Current(IntPtr hwnd,string expected) {
        return enabled && allowed && expected==token && hwnd!=IntPtr.Zero &&
            hwnd==allowedWindow && hwnd==Program.GetForegroundWindow() && RobloxForeground(hwnd);
    }
    IntPtr OnMouse(int code,IntPtr message,IntPtr data) {
        if(code<0) return Program.CallNextHookEx(hook,code,message,data);
        int msg=message.ToInt32();
        if(msg!=Down && msg!=Up) return Program.CallNextHookEx(hook,code,message,data);
        var e=(Program.HookData)Marshal.PtrToStructure(data,typeof(Program.HookData));
        // Every injected event, including the hub's own click, passes through.
        if((e.flags&3)!=0) return Program.CallNextHookEx(hook,code,message,data);
        if(msg==Down) {
            if(hold.Captured) return new IntPtr(1);
            if(!Current(allowedWindow,token)) return Program.CallNextHookEx(hook,code,message,data);
            hold.Begin(clock.ElapsedMilliseconds);
            captureWindow=allowedWindow;captureToken=token;
            return new IntPtr(1);
        }
        if(!hold.Captured) return Program.CallNextHookEx(hook,code,message,data);
        if(hold.Tap && Current(captureWindow,captureToken) && taps.Count<8)
            taps.Enqueue(new Tap { Window=captureWindow,Token=captureToken,At=clock.ElapsedMilliseconds });
        hold.End();lastWrite=-1000;
        return new IntPtr(1);
    }
    void WriteIntent(bool held) {
        if(String.IsNullOrEmpty(token)) return;
        string temp=intentPath+".tmp";
        try {
            var raw=json.Serialize(new { schema=IntentSchema,token=token,sequence=++seq,held=held,
                instance=instance,helperVersion="16.4.0-rc1" });
            File.WriteAllText(temp,raw,new UTF8Encoding(false));
            if(File.Exists(intentPath)) File.Replace(temp,intentPath,null);
            else File.Move(temp,intentPath);
            lastWrite=clock.ElapsedMilliseconds;previousHeld=held;
        } catch { try { File.Delete(temp); } catch {} }
    }
    void Tick() {
        long now=clock.ElapsedMilliseconds;
        var hwnd=Program.GetForegroundWindow();
        string freshToken;
        bool armed=ReadHeartbeat(out freshToken);
        if(!String.IsNullOrEmpty(freshToken) && token!=freshToken) {
            token=freshToken;seq=0;lastWrite=-1000;hold.Revoke();taps.Clear();
        }
        allowed=enabled && armed && RobloxForeground(hwnd);
        allowedWindow=allowed?hwnd:IntPtr.Zero;
        // Distinguish a temporary hub readiness dropout from loss of the actual
        // captured physical click. Foreground loss, helper pause or token change
        // always cancels permanently until a new physical Down edge.
        // A short missing hub heartbeat or native minigame only pauses dispatch.
        bool sameWindow=hwnd!=IntPtr.Zero && hwnd==captureWindow && RobloxForeground(hwnd);
        hold.Step(now,enabled,sameWindow,captureToken==token,armed);
        bool held=hold.Held && allowed;
        if(held!=previousHeld || now-lastWrite>=75) WriteIntent(held);
        while(taps.Count>0) {
            Tap tap=taps.Dequeue();
            if(!Current(tap.Window,tap.Token) || now-tap.At>250) continue;
            var inputs=new [] { Program.Edge(0x0002),Program.Edge(0x0004) };
            uint count=Program.SendInput(2,inputs,Marshal.SizeOf(typeof(Program.Input)));
            if(count==1) Program.SendInput(1,new [] { Program.Edge(0x0004) },Marshal.SizeOf(typeof(Program.Input)));
        }
        string label=!enabled?"FERAL input helper - paused":allowed?"FERAL input helper - active":"FERAL input helper - waiting for hub";
        if(tray.Text!=label) tray.Text=label;
    }
    void Toggle() {
        enabled=!enabled;
        if(!enabled) { allowed=false;hold.Revoke();taps.Clear();WriteIntent(false); }
    }
    protected override void ExitThreadCore() { Dispose(true);base.ExitThreadCore(); }
    protected override void Dispose(bool disposing) {
        if(!disposed) {
            disposed=true;allowed=false;hold.Revoke();
            try { timer.Stop();WriteIntent(false); } catch {}
            if(hook!=IntPtr.Zero) { Program.UnhookWindowsHookEx(hook);hook=IntPtr.Zero; }
            if(disposing) { timer.Dispose();hotkey.Dispose();tray.Visible=false;tray.Dispose(); }
            try { File.WriteAllText(statusPath,"STOPPED"); } catch {}
        }
        base.Dispose(disposing);
    }
}

