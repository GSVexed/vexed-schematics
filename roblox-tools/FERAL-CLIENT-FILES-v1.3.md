# Every distinct game client source — v1.3 review inventory

All 339 logical exports map to the following 221 distinct text bodies. All were
read by the automated surface audit. The companion [review](FERAL-CLIENT-CODE-REVIEW-v1.3.md)
explains the manual feature review and its limits. This table is a coverage
inventory, not a claim that every branch was manually proved or exercised.

Full paths, duplicate logical aliases, SHA-256 values, original export-file
references and literal API locations are in the [source index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json).
Compile status comes from the baseline compile-only audit; no exported code was run.

| ID | Client source | Group | Lines | Logical aliases | Syntax | Remote call sites |
|---|---|---|---:|---:|---|---:|
| S0000032 | FeralWorld/SkyCycle | shared logic/visuals | 282 | 1 | accepted | 0 |
| S0000033 | FeralWorld/NeedsConfig | configuration | 167 | 1 | rejected | 0 |
| S0000034 | FeralWorld/FeedFinder | shared logic/visuals | 382 | 1 | rejected | 0 |
| S0000035 | FeralWorld/Species | shared logic/visuals | 1103 | 1 | rejected | 0 |
| S0000036 | FeralWorld/AnimProfiles | data/assets | 10415 | 1 | rejected | 0 |
| S0000037 | FeralWorld/Forage | shared logic/visuals | 376 | 1 | accepted | 1 |
| S0000038 | FeralWorld/UITheme | shared logic/visuals | 933 | 1 | rejected | 0 |
| S0000039 | FeralWorld/SaveConfig | configuration | 24 | 1 | accepted | 0 |
| S0000040 | FeralWorld/NPCConfig | configuration | 595 | 1 | rejected | 0 |
| S0000041 | FeralWorld/CombatConfig | configuration | 599 | 1 | rejected | 0 |
| S0000042 | FeralWorld/WaterLooks | shared logic/visuals | 142 | 1 | accepted | 0 |
| S0000043 | FeralWorld/AnimalCalls | data/assets | 2592 | 1 | accepted | 0 |
| S0000044 | FeralWorld/WeatherConfig | configuration | 175 | 1 | rejected | 0 |
| S0000045 | FeralWorld/AmberConfig | configuration | 56 | 1 | rejected | 0 |
| S0000046 | FeralWorld/DevConfig | configuration | 26 | 1 | rejected | 0 |
| S0000047 | FeralWorld/SoundboardList | data/assets | 4235 | 1 | rejected | 0 |
| S0000048 | FeralWorld/MapSpots | shared logic/visuals | 109 | 1 | rejected | 0 |
| S0000049 | FeralWorld/MapConfig | configuration | 43 | 1 | rejected | 0 |
| S0000050 | FeralWorld/SoundConfig | configuration | 140 | 1 | rejected | 0 |
| S0000051 | FeralWorld/PackConfig | configuration | 187 | 1 | rejected | 0 |
| S0000052 | FeralWorld/CameraConfig | configuration | 90 | 1 | accepted | 0 |
| S0000053 | FeralWorld/QuestConfig | configuration | 475 | 1 | accepted | 0 |
| S0000054 | FeralWorld/ShopConfig | configuration | 514 | 1 | rejected | 0 |
| S0000055 | FeralWorld/DeathConfig | configuration | 3 | 1 | accepted | 0 |
| S0000056 | FeralWorld/AbilityConfig | configuration | 2462 | 1 | rejected | 0 |
| S0000057 | FeralWorld/NameConfig | configuration | 164 | 1 | accepted | 0 |
| S0000058 | FeralWorld/PlacesConfig | configuration | 21 | 1 | accepted | 0 |
| S0000059 | FeralWorld/SpawnConfig | configuration | 66 | 1 | accepted | 0 |
| S0000060 | FeralWorld/SettingsConfig | configuration | 48 | 1 | accepted | 0 |
| S0000061 | FeralWorld/OnboardingConfig | configuration | 821 | 1 | rejected | 0 |
| S0000062 | FeralWorld/TutorialConfig | configuration | 220 | 1 | rejected | 0 |
| S0000063 | FeralWorld/AfkConfig | configuration | 12 | 1 | accepted | 0 |
| S0000064 | FeralWorld/RewardConfig | configuration | 51 | 1 | rejected | 0 |
| S0000065 | FeralWorld/CoatConfig | configuration | 571 | 1 | rejected | 0 |
| S0000066 | FeralWorld/DiveConfig | configuration | 176 | 1 | accepted | 0 |
| S0000067 | FeralWorld/TerritoryConfig | configuration | 460 | 1 | rejected | 0 |
| S0000068 | FeralWorld/FishConfig | configuration | 84 | 1 | rejected | 0 |
| S0000069 | FeralWorld/FishPath | shared logic/visuals | 61 | 1 | accepted | 0 |
| S0000070 | FeralWorld/SurvivalConfig | configuration | 116 | 1 | accepted | 0 |
| S0000071 | FeralWorld/PhonePreview | shared logic/visuals | 352 | 1 | accepted | 0 |
| S0000072 | FeralWorld/GrowthConfig | configuration | 211 | 1 | rejected | 0 |
| S0000073 | FeralWorld/CallMixConfig | configuration | 36 | 1 | accepted | 0 |
| S0000074 | FeralWorld/HudConfig | configuration | 889 | 1 | rejected | 0 |
| S0000075 | FeralWorld/MouseConfig | configuration | 81 | 1 | accepted | 0 |
| S0000076 | FeralWorld/CarcassConfig | configuration | 50 | 1 | rejected | 0 |
| S0000077 | FeralWorld/PassiveConfig | configuration | 389 | 1 | rejected | 0 |
| S0000078 | FeralWorld/FeralTrunks | shared logic/visuals | 806 | 1 | accepted | 0 |
| S0000079 | FeralWorld/ScentConfig | configuration | 95 | 1 | rejected | 0 |
| S0000080 | FeralWorld/JoystickConfig | configuration | 26 | 1 | accepted | 0 |
| S0000081 | FeralWorld/GoalConfig | configuration | 90 | 1 | rejected | 0 |
| S0000082 | FeralWorld/CinematicConfig | configuration | 770 | 1 | rejected | 0 |
| S0000083 | FeralWorld/CritterConfig | configuration | 84 | 1 | accepted | 0 |
| S0000084 | FeralWorld/CrouchConfig | configuration | 18 | 1 | accepted | 0 |
| S0000085 | FeralWorld/StatusConfig | configuration | 489 | 1 | rejected | 0 |
| S0000086 | FeralWorld/SnakeProfiles | shared logic/visuals | 472 | 1 | rejected | 0 |
| S0000087 | FeralWorld/SnakeRig | shared logic/visuals | 3336 | 1 | accepted | 0 |
| S0000088 | FeralWorld/AccessConfig | configuration | 156 | 1 | accepted | 0 |
| S0000089 | FeralWorld/LitterConfig | configuration | 91 | 1 | accepted | 0 |
| S0000090 | FeralWorld/CarryConfig | configuration | 316 | 1 | accepted | 0 |
| S0000091 | FeralWorld/WayArrow | shared logic/visuals | 138 | 1 | accepted | 0 |
| S0000092 | FeralWorld/PerfConfig | configuration | 64 | 1 | accepted | 0 |
| S0000093 | FeralWorld/FlightConfig | configuration | 162 | 1 | accepted | 0 |
| S0000094 | FeralWorld/BirdProfiles | shared logic/visuals | 850 | 1 | rejected | 0 |
| S0000095 | FeralWorld/BirdRig | shared logic/visuals | 4106 | 1 | rejected | 0 |
| S0000096 | FeralWorld/OverviewConfig | configuration | 28 | 1 | accepted | 0 |
| S0000097 | FeralWorld/DeathRollPlan | shared logic/visuals | 150 | 1 | accepted | 0 |
| S0000098 | FeralWorld/UpdateNoticeConfig | configuration | 3 | 1 | accepted | 0 |
| S0000099 | FeralWorld/WedgeBar | shared logic/visuals | 174 | 1 | accepted | 0 |
| S0000100 | FeralWorld/DroughtConfig | configuration | 42 | 1 | accepted | 0 |
| S0000101 | FeralWorld/AdminConfig | configuration | 31 | 1 | accepted | 0 |
| S0000102 | FeralWorld/FloodConfig | configuration | 34 | 1 | accepted | 0 |
| S0000103 | FeralWorld/VenomConfig | configuration | 170 | 1 | rejected | 0 |
| S0000104 | FeralWorld/VenomUI | shared logic/visuals | 362 | 1 | accepted | 0 |
| S0000105 | FeralWorld/ScavengerConfig | configuration | 53 | 1 | accepted | 0 |
| S0000106 | FeralWorld/TalonLockMath | shared logic/visuals | 193 | 1 | accepted | 0 |
| S0000107 | FeralWorld/ElderConfig | configuration | 342 | 1 | rejected | 0 |
| S0000108 | FeralWorld/ElderIcons | shared logic/visuals | 169 | 1 | accepted | 0 |
| S0000109 | FeralWorld/ElderPaint | shared logic/visuals | 183 | 1 | rejected | 0 |
| S0000110 | FeralWorld/CoatRecolor | shared logic/visuals | 496 | 1 | accepted | 0 |
| S0000111 | FeralWorld/CoatMasks | data/assets | 55 | 1 | accepted | 0 |
| S0000112 | FeralWorld/RegrowConfig | configuration | 87 | 1 | accepted | 0 |
| S0000113 | FeralWorld/WolfRunClip | shared logic/visuals | 2153 | 1 | accepted | 0 |
| S0000114 | FeralWorld/GiftConfig | configuration | 24 | 1 | accepted | 0 |
| S0000115 | FeralWorld/StrideFeelConfig | configuration | 9 | 1 | accepted | 0 |
| S0000116 | FeralWorld/FilmConfig | configuration | 343 | 1 | rejected | 0 |
| S0000117 | FeralWorld/JumpLeapConfig | configuration | 48 | 1 | rejected | 0 |
| S0000119 | FeralWorld/Skies/WolfValley | shared logic/visuals | 299 | 1 | accepted | 0 |
| S0000121 | FeralWorld/Clutter/Data_WolfValley | data/assets | 26 | 1 | rejected | 0 |
| S0000122 | FeralWorld/Clutter/Data_WolfValley/Part_1 | data/assets | 3 | 11 | accepted | 0 |
| S0003033 | FeralWorld/ElderScars/m137692634917020 | data/assets | 3 | 1 | accepted | 0 |
| S0003034 | FeralWorld/ElderScars/m107332642246280 | data/assets | 3 | 1 | accepted | 0 |
| S0003035 | FeralWorld/ElderScars/m139535328844626 | data/assets | 3 | 1 | accepted | 0 |
| S0003036 | FeralWorld/ElderScars/m79669013241516 | data/assets | 3 | 1 | accepted | 0 |
| S0003037 | FeralWorld/ElderScars/m122352480944033 | data/assets | 3 | 1 | accepted | 0 |
| S0003038 | FeralWorld/ElderScars/m129775822294194 | data/assets | 3 | 1 | accepted | 0 |
| S0003039 | FeralWorld/ElderScars/m78907218241567 | data/assets | 3 | 1 | accepted | 0 |
| S0003040 | FeralWorld/ElderScars/m132430804892530 | data/assets | 3 | 1 | accepted | 0 |
| S0003041 | FeralWorld/ElderScars/m90663438088693 | data/assets | 3 | 1 | accepted | 0 |
| S0003042 | FeralWorld/ElderScars/m91228914211019 | data/assets | 3 | 1 | accepted | 0 |
| S0003043 | FeralWorld/ElderScars/m72625564930302 | data/assets | 3 | 1 | accepted | 0 |
| S0003044 | FeralWorld/ElderScars/m123353439493569 | data/assets | 3 | 1 | accepted | 0 |
| S0003045 | FeralWorld/ElderScars/m127857292691763 | data/assets | 3 | 1 | accepted | 0 |
| S0003046 | FeralWorld/ElderScars/m128113853257572 | data/assets | 3 | 1 | accepted | 0 |
| S0003047 | FeralWorld/ElderScars/m91510416362415 | data/assets | 3 | 1 | accepted | 0 |
| S0003048 | FeralWorld/ElderScars/m95476813909982 | data/assets | 3 | 1 | accepted | 0 |
| S0003049 | FeralWorld/ElderScars/m108375670744042 | data/assets | 3 | 1 | accepted | 0 |
| S0003050 | FeralWorld/ElderScars/m106024804610061 | data/assets | 3 | 1 | accepted | 0 |
| S0003051 | FeralWorld/ElderScars/m107628582598118 | data/assets | 3 | 1 | accepted | 0 |
| S0003052 | FeralWorld/ElderScars/m126976076731119 | data/assets | 3 | 1 | accepted | 0 |
| S0003053 | FeralWorld/ElderScars/m112786107721021 | data/assets | 3 | 2 | accepted | 0 |
| S0003054 | FeralWorld/ElderScars/m125189987010586 | data/assets | 3 | 1 | accepted | 0 |
| S0003055 | FeralWorld/ElderScars/m108600600442871 | data/assets | 3 | 1 | accepted | 0 |
| S0003056 | FeralWorld/ElderScars/m130693439690712 | data/assets | 3 | 1 | accepted | 0 |
| S0003620 | PlayerScripts/WolfController | client controllers/UI | 8308 | 2 | accepted | 41 |
| S0003621 | PlayerScripts/WolfAnimClient | client controllers/UI | 18213 | 2 | rejected | 0 |
| S0003622 | PlayerScripts/WolfMuteDefaultSounds | client controllers/UI | 55 | 2 | accepted | 0 |
| S0003623 | PlayerScripts/FeralSkyClient | client controllers/UI | 48 | 2 | accepted | 0 |
| S0003624 | PlayerScripts/FeralClutterClient | client controllers/UI | 698 | 2 | accepted | 0 |
| S0003625 | PlayerScripts/FeralMenu | client controllers/UI | 20872 | 2 | rejected | 16 |
| S0003626 | PlayerScripts/FeralHUD | client controllers/UI | 13791 | 2 | rejected | 0 |
| S0003627 | PlayerScripts/FeralCallsInput | client controllers/UI | 43 | 2 | accepted | 1 |
| S0003628 | PlayerScripts/FeralFootsteps | client controllers/UI | 365 | 2 | accepted | 0 |
| S0003629 | PlayerScripts/FeralWaterClient | client controllers/UI | 172 | 2 | accepted | 0 |
| S0003630 | PlayerScripts/FeralCombatClient | client controllers/UI | 4293 | 2 | rejected | 0 |
| S0003631 | PlayerScripts/FeralAtmosphere | client controllers/UI | 1244 | 2 | accepted | 0 |
| S0003632 | PlayerScripts/FeralSoundboard | client controllers/UI | 1213 | 2 | accepted | 0 |
| S0003633 | PlayerScripts/FeralMap | client controllers/UI | 3536 | 2 | accepted | 0 |
| S0003634 | PlayerScripts/FeralCombatTag | client controllers/UI | 590 | 2 | accepted | 0 |
| S0003635 | PlayerScripts/FeralUISounds | client controllers/UI | 83 | 2 | accepted | 0 |
| S0003636 | PlayerScripts/FeralAmbience | client controllers/UI | 350 | 2 | accepted | 0 |
| S0003637 | PlayerScripts/FeralWater | client controllers/UI | 531 | 2 | accepted | 0 |
| S0003638 | PlayerScripts/FeralNightVision | client controllers/UI | 522 | 2 | rejected | 0 |
| S0003639 | PlayerScripts/FeralPacksUI | client controllers/UI | 3764 | 2 | rejected | 2 |
| S0003640 | PlayerScripts/FeralFeedSounds | client controllers/UI | 347 | 2 | accepted | 0 |
| S0003641 | PlayerScripts/FeralRunCamera | client controllers/UI | 520 | 2 | accepted | 0 |
| S0003642 | PlayerScripts/FeralQuestsUI | client controllers/UI | 4002 | 2 | accepted | 1 |
| S0003643 | PlayerScripts/FeralStarterUI | client controllers/UI | 1587 | 2 | accepted | 1 |
| S0003644 | PlayerScripts/FeralShopUI | client controllers/UI | 5310 | 2 | accepted | 3 |
| S0003645 | PlayerScripts/FeralDeathUI | client controllers/UI | 2096 | 2 | accepted | 5 |
| S0003646 | PlayerScripts/FeralCombatMusic | client controllers/UI | 85 | 2 | accepted | 0 |
| S0003647 | PlayerScripts/FeralLungeUI | client controllers/UI | 2710 | 2 | accepted | 8 |
| S0003648 | PlayerScripts/FeralDust | client controllers/UI | 526 | 2 | rejected | 0 |
| S0003649 | PlayerScripts/FeralNameTags | client controllers/UI | 149 | 2 | accepted | 0 |
| S0003650 | PlayerScripts/FeralPlacesUI | client controllers/UI | 965 | 2 | accepted | 0 |
| S0003651 | PlayerScripts/FeralDbgTools | client controllers/UI | 39 | 2 | accepted | 0 |
| S0003652 | PlayerScripts/FeralSettingsUI | client controllers/UI | 996 | 2 | accepted | 8 |
| S0003653 | PlayerScripts/FeralOnbClient | client controllers/UI | 3712 | 2 | rejected | 4 |
| S0003654 | PlayerScripts/FeralTutorialUI | client controllers/UI | 4373 | 2 | accepted | 5 |
| S0003655 | PlayerScripts/FeralPackMarkers | client controllers/UI | 488 | 2 | accepted | 0 |
| S0003656 | PlayerScripts/FeralActions | client controllers/UI | 633 | 2 | accepted | 1 |
| S0003657 | PlayerScripts/FeralAfk | client controllers/UI | 407 | 2 | accepted | 1 |
| S0003658 | PlayerScripts/FeralRewardsUI | client controllers/UI | 3300 | 2 | rejected | 8 |
| S0003659 | PlayerScripts/FeralCoatsUI | client controllers/UI | 2056 | 2 | accepted | 3 |
| S0003660 | PlayerScripts/FeralDive | client controllers/UI | 1942 | 2 | rejected | 0 |
| S0003661 | PlayerScripts/FeralFishClient | client controllers/UI | 656 | 2 | accepted | 2 |
| S0003662 | PlayerScripts/FeralSurvivalUI | client controllers/UI | 2950 | 2 | accepted | 0 |
| S0003663 | PlayerScripts/FeralElderUI | client controllers/UI | 2251 | 2 | accepted | 1 |
| S0003664 | PlayerScripts/FeralCallMix | client controllers/UI | 935 | 2 | accepted | 0 |
| S0003665 | PlayerScripts/FeralMouseLock | client controllers/UI | 182 | 2 | accepted | 0 |
| S0003666 | PlayerScripts/FeralCarcassFX | client controllers/UI | 184 | 2 | accepted | 0 |
| S0003667 | PlayerScripts/FeralClimb | client controllers/UI | 1143 | 2 | rejected | 2 |
| S0003668 | PlayerScripts/FeralPassiveUI | client controllers/UI | 922 | 2 | accepted | 0 |
| S0003669 | PlayerScripts/FeralCallRing | client controllers/UI | 606 | 2 | accepted | 0 |
| S0003670 | PlayerScripts/FeralTestNewUI | client controllers/UI | 701 | 2 | accepted | 2 |
| S0003671 | PlayerScripts/FeralSniff | client controllers/UI | 2779 | 2 | accepted | 2 |
| S0003672 | PlayerScripts/FeralJoystick | client controllers/UI | 602 | 2 | accepted | 0 |
| S0003673 | PlayerScripts/FeralGoalUI | client controllers/UI | 3624 | 2 | accepted | 6 |
| S0003674 | PlayerScripts/FeralUIBlur | client controllers/UI | 173 | 2 | accepted | 0 |
| S0003675 | PlayerScripts/FeralTracking | client controllers/UI | 116 | 2 | accepted | 0 |
| S0003676 | PlayerScripts/FeralCinematic | client controllers/UI | 9425 | 2 | accepted | 8 |
| S0003677 | PlayerScripts/FeralUIKit | client controllers/UI | 1433 | 2 | rejected | 0 |
| S0003678 | PlayerScripts/FeralCritters | client controllers/UI | 851 | 2 | accepted | 0 |
| S0003679 | PlayerScripts/FeralRollDust | client controllers/UI | 263 | 2 | accepted | 0 |
| S0003680 | PlayerScripts/FeralCrouchClient | client controllers/UI | 162 | 2 | accepted | 3 |
| S0003681 | PlayerScripts/FeralStatusUI | client controllers/UI | 1032 | 2 | accepted | 0 |
| S0003682 | PlayerScripts/SnakeAnimClient | client controllers/UI | 392 | 2 | accepted | 0 |
| S0003683 | PlayerScripts/FeralThriveUI | client controllers/UI | 96 | 2 | accepted | 0 |
| S0003684 | PlayerScripts/FeralDenDiveClient | client controllers/UI | 2615 | 2 | accepted | 5 |
| S0003685 | PlayerScripts/FeralTurfSight | client controllers/UI | 183 | 2 | accepted | 0 |
| S0003686 | PlayerScripts/FeralWildMusic | client controllers/UI | 313 | 2 | accepted | 0 |
| S0003687 | PlayerScripts/FeralChatTag | client controllers/UI | 107 | 2 | accepted | 0 |
| S0003688 | PlayerScripts/FeralElephantClient | client controllers/UI | 887 | 2 | accepted | 4 |
| S0003689 | PlayerScripts/FeralCarryClient | client controllers/UI | 558 | 2 | accepted | 4 |
| S0003690 | PlayerScripts/FeralTerritoryHUD | client controllers/UI | 5557 | 2 | rejected | 0 |
| S0003691 | PlayerScripts/FeralWaterPlantLOD | client controllers/UI | 128 | 2 | accepted | 0 |
| S0003692 | PlayerScripts/FeralFlight | client controllers/UI | 1722 | 2 | rejected | 12 |
| S0003693 | PlayerScripts/BirdAnimClient | client controllers/UI | 588 | 2 | accepted | 0 |
| S0003694 | PlayerScripts/FeralFlightProbe | client controllers/UI | 179 | 2 | accepted | 0 |
| S0003695 | PlayerScripts/FeralTalonView | client controllers/UI | 1282 | 2 | accepted | 0 |
| S0003696 | PlayerScripts/FeralGrowUI | client controllers/UI | 1719 | 2 | accepted | 0 |
| S0003697 | PlayerScripts/FeralOverview | client controllers/UI | 1151 | 2 | accepted | 0 |
| S0003698 | PlayerScripts/FeralPackPromptUI | client controllers/UI | 693 | 2 | accepted | 2 |
| S0003699 | PlayerScripts/FeralSaveAdminClient | client controllers/UI | 597 | 2 | rejected | 2 |
| S0003700 | PlayerScripts/FeralTextFit | client controllers/UI | 349 | 2 | rejected | 0 |
| S0003701 | PlayerScripts/FeralBisonFX | client controllers/UI | 423 | 2 | accepted | 0 |
| S0003702 | PlayerScripts/FeralUpdateNoticeUI | client controllers/UI | 213 | 2 | accepted | 0 |
| S0003703 | PlayerScripts/FeralStarterPackUI | client controllers/UI | 675 | 2 | accepted | 2 |
| S0003704 | PlayerScripts/FeralWolfBKey | client controllers/UI | 102 | 2 | accepted | 1 |
| S0003705 | PlayerScripts/FeralChatPill | client controllers/UI | 337 | 2 | accepted | 0 |
| S0003706 | PlayerScripts/FeralAdminUI | client controllers/UI | 827 | 2 | accepted | 12 |
| S0003707 | PlayerScripts/FeralEventHUD | client controllers/UI | 427 | 2 | accepted | 0 |
| S0003708 | PlayerScripts/FeralRunVarKey | client controllers/UI | 314 | 2 | accepted | 2 |
| S0003709 | PlayerScripts/FeralTitlePack | client controllers/UI | 1157 | 2 | rejected | 1 |
| S0003710 | PlayerScripts/FeralVenomClient | client controllers/UI | 350 | 2 | accepted | 0 |
| S0003711 | PlayerScripts/FeralPadR3 | client controllers/UI | 53 | 2 | accepted | 0 |
| S0003712 | PlayerScripts/FeralScavengersClient | client controllers/UI | 771 | 2 | accepted | 0 |
| S0003713 | PlayerScripts/FeralTalonLockClient | client controllers/UI | 1239 | 2 | accepted | 5 |
| S0003714 | PlayerScripts/FeralHippoClient | client controllers/UI | 1123 | 2 | accepted | 3 |
| S0003715 | PlayerScripts/FeralDiveBombClient | client controllers/UI | 2274 | 2 | accepted | 18 |
| S0003716 | PlayerScripts/FeralElderLook | client controllers/UI | 786 | 2 | accepted | 0 |
| S0003717 | PlayerScripts/FeralPerfMode | client controllers/UI | 533 | 2 | accepted | 0 |
| S0003718 | PlayerScripts/FeralCoatRecolor | client controllers/UI | 975 | 2 | accepted | 0 |
| S0003719 | PlayerScripts/FeralGiveUI | client controllers/UI | 1607 | 2 | rejected | 1 |
| S0003720 | PlayerScripts/FeralDeathSense | client controllers/UI | 246 | 2 | accepted | 0 |
| S0003721 | PlayerScripts/FeralPerfTest | client controllers/UI | 915 | 2 | accepted | 0 |
| S0003722 | PlayerScripts/FeralFilm | client controllers/UI | 3566 | 2 | accepted | 9 |
| S0003723 | PlayerScripts/FeralKingsClient | client controllers/UI | 1177 | 2 | rejected | 2 |
| S0003724 | PlayerScripts/FeralNewsUI | client controllers/UI | 745 | 2 | accepted | 2 |
| S0003725 | PlayerScripts/RbxCharacterSounds | client controllers/UI | 585 | 2 | rejected | 0 |
| S0003726 | PlayerScripts/RbxCharacterSounds/AtomicBinding | client controllers/UI | 286 | 2 | accepted | 0 |
| S0011945 | game/StarterPlayer/StarterCharacterScripts/Animate | shared logic/visuals | 10 | 1 | accepted | 0 |
