extends SceneTree

# ECHO//LINE — Flow diagnostic test (Phase 9)

func _init():
    _run_async()

func _run_async():
    print("\n========== ECHO//LINE Flow Diagnostic ==========")

    # ----- Step 1: intro -----
    var intro = load("res://scenes/intro.tscn").instantiate()
    root.add_child(intro)
    await process_frame
    var intro_paths = {
        "title_label": "Root/TitleStack/TitleLabel",
        "subtitle_label": "Root/TitleStack/SubtitleLabel",
        "arabic_label": "Root/TitleStack/ArabicLabel",
        "logo_container": "Root/LogoContainer",
        "skip_btn": "Root/SkipButton",
        "progress_bar": "Root/ProgressBar",
        "background": "Background",
    }
    var intro_missing = []
    for n in intro_paths:
        if not intro.get_node_or_null(intro_paths[n]):
            intro_missing.append(n)
    if intro_missing.is_empty():
        print("[PASS] [intro] all 7 @onready nodes resolved")
    else:
        print("[FAIL] [intro] missing: " + str(intro_missing))
    intro.queue_free()
    await process_frame

    # ----- Step 2: main_menu -----
    var mm = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(mm)
    await process_frame
    var mm_paths = {
        "play_btn": "SplitContainer/LeftPanel/LeftScroll/LeftVBox/PlayButton",
        "tutorial_btn": "SplitContainer/LeftPanel/LeftScroll/LeftVBox/TutorialButton",
        "settings_btn": "SplitContainer/RightPanel/RightScroll/RightVBox/SettingsButton",
        "language_btn": "SplitContainer/RightPanel/RightScroll/RightVBox/LanguageButton",
        "credits_btn": "SplitContainer/RightPanel/RightScroll/RightVBox/CreditsButton",
        "status_label": "StatusLabel",
        "server_indicator": "ServerIndicator",
    }
    var mm_missing = []
    for n in mm_paths:
        if not mm.get_node_or_null(mm_paths[n]):
            mm_missing.append(n + " @ " + mm_paths[n])
    if mm_missing.is_empty():
        print("[PASS] [main_menu] all 7 @onready nodes resolved")
    else:
        print("[FAIL] [main_menu] missing nodes: " + str(mm_missing))

    # Check that ALL split container children exist
    var sc = mm.get_node_or_null("SplitContainer")
    if sc:
        var lc = sc.get_child_count()
        print("  [INFO] SplitContainer has " + str(lc) + " children")
        for c in sc.get_children():
            print("    - " + c.name + " (" + c.get_class() + ")")
    mm.queue_free()
    await process_frame

    # ----- Step 3: main.tscn with LobbyView -----
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    var lv = main.get_node_or_null("UI/LobbyView")
    if not lv:
        print("[FAIL] [lobby_view] UI/LobbyView not found in main.tscn")
        main.queue_free()
        quit()
        return

    var lv_paths = {
        "room_code_input": "Panel/VBox/HeaderRow/RoomCodeInput",
        "join_btn": "Panel/VBox/HeaderRow/JoinButton",
        "create_btn": "Panel/VBox/HeaderRow/CreateButton",
        "past_card": "Panel/VBox/CardsRow/PastCard",
        "present_card": "Panel/VBox/CardsRow/PresentCard",
        "future_card": "Panel/VBox/CardsRow/FutureCard",
        "ready_btn": "Panel/VBox/ActionRow/ReadyButton",
        "leave_btn": "Panel/VBox/ActionRow/LeaveButton",
        "back_btn": "BackButton",
        "status_label": "Panel/VBox/StatusLabel",
    }
    var lv_missing = []
    for n in lv_paths:
        if not lv.get_node_or_null(lv_paths[n]):
            lv_missing.append(n + " @ " + lv_paths[n])
    if lv_missing.is_empty():
        print("[PASS] [lobby_view] all 10 in-scene @onready nodes resolved")
    else:
        print("[FAIL] [lobby_view] missing nodes: " + str(lv_missing))

    # Check dynamic creation
    print("  [INFO] LobbyView Panel children: " + str(lv.get_node("Panel/VBox").get_child_count()))
    for c in lv.get_node("Panel/VBox").get_children():
        print("    - " + c.name + " (" + c.get_class() + ") visible=" + str(c.visible))

    main.queue_free()
    await process_frame

    # ----- Step 4: NetworkClient connectivity -----
    var nc = root.get_node_or_null("NetworkClient")
    if not nc:
        print("[FAIL] [network] NetworkClient autoload missing")
    else:
        if nc.is_socket_connected():
            print("[PASS] [network] NetworkClient connected to Render")
            print("  sid=" + str(nc.get("sid")) + " server=" + str(nc.get("server_base")))
        else:
            print("[FAIL] [network] NetworkClient not connected (Render may be down)")

    print("\n========== END DIAGNOSTIC ==========")
    quit()
