-- Cyberslop Sound Gains: level per custom-sound row (event name -> gain). 1.0 = as recorded. Linear, so
-- 0.5 = -6 dB, 0.25 = -12 dB, 0.1 = -20 dB, 0.05 = -26 dB. Rows not listed keep the level AudioXL gives them
-- (1.0 for every REDmod row). For silence use 0.001 rather than 0 (AudioXL reads 0 as "what the row says" in its
-- play calls; not verified for SetGain).
-- Values copied on 2026-10-27 from the REDmods' info.json (mods\<mod>\info.json); since AudioXL went in this file
-- is where they take effect. Silent files need no entry: Mute V's Pain Voice (muted.wav) and the four
-- UltimateMonowire energy rows ([silent].wav) are silence as recorded.
return {
    -- Dash V3 (dodge)
    lcm_dash = 0.05,
    -- Jump_Alt V3 (double jump)
    lcm_player_double_jump = 0.10,
    -- SandevistanFate (Kerenzikov enter / exit)
    time_dilation_kereznikov_enter = 0.15,
    time_dilation_kereznikov_exit = 0.15,
    -- Sharingan (Sandevistan enter / exit)
    time_dilation_sandevistan_enter = 0.15,
    time_dilation_sandevistan_exit = 0.15,
    -- UltimateMonowire (first equip): row removed 2026-11-23. The mod's sounds are gone (only its Vortex marker is
    -- left, no copy under AudioXL), so the row was never registered: every launch retried it for 91 s and logged
    -- ~45 lines (CyberslopSoundGains.log 1.96 MB). Put it back only with UltimateMonowire's sounds.
    -- w_cyb_nano_wire_first_equip = 0.5,
    -- E3 Style SFX (Nexus 7289, 2026-10-28): "a bit too loud", so half the author's info.json levels (-6 dB)
    ui_focus_mode_zooming_in_enter = 0.5,
    ui_focus_mode_zooming_in_exit = 0.5,
    ui_focus_mode_zooming_in_step_change = 0.5,
    ui_focus_mode_scanning_done = 0.5,
    ui_gui_close = 0.5,
    ui_focus_mode_scanning_loop_start = 0.4,
    ui_gui_open = 0.4,
    ui_menu_onpress = 0.15,
    ui_menu_open = 0.4,
    ui_hacking_press = 0.4,
    -- (ui_main_menu_cc_confirmation_screen_close 1.5 removed 2026-11-08: SFX Toggle's main menu mute covers it)
    ui_phone_sms = 0.25,

    -- 2026-11-08 audio pass (measured with ffmpeg ebur128): stingers brought to
    -- a momentary max of about -18 LUFS, 3 dB over V's own voice lines; the old gains went over full scale.
    -- Drug Dealer (AudioXL rows, plain AudioSystem.Play), was -> now
    dd_terror = 0.45,              -- 2.0 -> 0.45 (-13.0 dB)
    dd_partial_drug_deal = 0.32,   -- 1.2 -> 0.32 (-11.5 dB)
    dd_nightmarket = 0.4,          -- 1.2 -> 0.4 (-9.5 dB)
    dd_assassination = 0.43,       -- 1.2 -> 0.43 (-8.9 dB)
    dd_lab_ambush = 0.25,          -- 0.7 -> 0.25 (-8.9 dB)
    dd_ncpd_drug_bust = 0.19,      -- 0.5 -> 0.19 (-8.4 dB)
    dd_raid_w = 0.18,              -- 0.3 -> 0.18 (-4.4 dB)
    dd_product_prepared = 0.44,    -- 0.8 -> 0.44 (-5.2 dB)
    dd_drug_deal_l = 1.0,          -- 2.0 -> 1.0 (-6.0 dB)
    -- Injuries (AudioXL rows)
    injuries_healed = 0.45,        -- 1.2 -> 0.45 (-8.5 dB)
    injuries_failed = 1.0,         -- 2.0 -> 1.0 (-6.0 dB)
    -- Anti-Theft Measures (positioned alarm loop)
    atm_alarm = 0.4,               -- 0.8 -> 0.4 (-6.0 dB)
    -- Melee finishers (REDmods fasterfinish / fasterfinhotfix / finishifix2), 1.0 -> 0.5 (-6.0 dB)
    w_melee_finisher_axe_01 = 0.5,
    w_melee_finisher_axe_02 = 0.5,
    w_melee_finisher_katana02 = 0.5,
    w_melee_finisher_one_handed_blade01 = 0.5,
    w_melee_finisher_one_handed_blade02 = 0.5,
    w_melee_finisher_one_handed_blunt_01 = 0.5,
    w_melee_finisher_one_handed_blunt_02 = 0.5,
    w_melee_finisher_sledgehammer01 = 0.5,
    w_melee_finisher_sledgehammer02 = 0.5,
    w_melee_finisher_two_handed_blunt01 = 0.5,
    w_melee_finisher_two_handed_blunt02 = 0.5,
    -- Playable Guitar Weapon: song 05 is about 3 dB over the other 19
    zeusico_guitar_hero_song_05 = 0.7, -- 1.0 -> 0.7 (-3.1 dB)
}
