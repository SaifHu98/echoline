extends SceneTree

# ECHO//LINE — Full flow test (Phase 9) — runs WITH autoloads

var nc
var flow_ok: bool = false

func _initialize():
    # Runs after autoloads are ready
    _run_async.call_deferred()

func _run_async():
    print("\n========== ECHO//LINE Full Flow Test ==========")

    print("\n[STEP 1] Load main.tscn (lobby scene)")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    await process_frame

    var lv = main.get_node_or_null("UI/LobbyView")
    if not lv:
        print("[FAIL] UI/LobbyView missing")
        quit()
        return
    print("  LobbyView present")

    print("\n[STEP 2] Check rooms_panel dynamic creation")
    await process_frame
    var rp = lv.get_node_or_null("Panel/VBox/RoomsPanel")
    if rp:
        print("  [PASS] RoomsPanel created dynamically")
        print("  Type: " + rp.get_class())
        print("  Children: " + str(rp.get_child_count()))
        for c in rp.get_children():
            print("    - " + c.name + " (" + c.get_class() + ")")
        var rb = rp.find_child("RefreshButton", true, false)
        if rb:
            print("  [PASS] RefreshButton exists at: " + str(rb.get_path()))
            print("    Text: " + rb.text)
            print("    Size: " + str(rb.custom_minimum_size))
        else:
            print("  [FAIL] RefreshButton NOT found under RoomsPanel")
    else:
        print("  [FAIL] RoomsPanel NOT created")

    print("\n[STEP 3] Check StatusLabel")
    var sl = lv.get_node_or_null("Panel/VBox/StatusLabel")
    if sl:
        print("  [PASS] StatusLabel present, text: '" + sl.text + "'")
    else:
        print("  [FAIL] StatusLabel missing")

    print("\n[STEP 4] Check NetworkClient connectivity")
    nc = root.get_node_or_null("NetworkClient")
    if not nc:
        print("  [FAIL] NetworkClient autoload missing")
        quit()
        return
    print("  NetworkClient present, connected: " + str(nc.is_socket_connected()))
    if not nc.is_socket_connected():
        print("  Triggering connect_to_server()...")
        nc.connect_to_server(OS.get_environment("ECHOLINE_TEST_SERVER"))
        await create_timer(4.0).timeout
        print("  After 4s, connected: " + str(nc.is_socket_connected()))

    if nc.has_method("http_list_rooms"):
        print("\n[STEP 5] Fetch rooms list...")
        nc.http_list_rooms("en", _on_rooms)
        await create_timer(5.0).timeout
    else:
        print("  [FAIL] http_list_rooms method missing")
        quit()

func _on_rooms(result: Dictionary):
    print("\n[STEP 6] Room list response")
    if result and result.get("success"):
        var rooms = result.get("rooms", [])
        print("  [PASS] Got " + str(rooms.size()) + " rooms")
        for r in rooms:
            print("    - " + str(r.get("code", "?")) + " | players=" + str(r.get("playerCount", "?")) +
                " / max=" + str(r.get("maxPlayers", "?")) +
                " | private=" + str(r.get("isPrivate", "?")) +
                " | status=" + str(r.get("status", "?")))
    else:
        print("  [FAIL] Room list failed: " + str(result))

    print("\n[STEP 7] Verify lobby_view script exposes required methods")
    var lv = root.get_node_or_null("Main/UI/LobbyView")
    if lv:
        for m in ["_show_create_modal", "_do_create", "_show_join_password_modal",
                "_do_join", "_on_create_pressed", "_on_join_pressed",
                "_ensure_rooms_panel", "_update_localized_texts",
                "_show_input_state", "_show_timeline_picker_state"]:
            if lv.has_method(m):
                print("  [PASS] " + m + " exists")
            else:
                print("  [FAIL] " + m + " missing")

    print("\n[STEP 8] Trigger room creation flow")
    if lv:
        # Directly call _do_create to test the create_room path
        print("  Calling _do_create with player_name=FlowTest, max=4, password='flow123', locale='en'")
        if lv.has_method("_do_create"):
            lv._do_create("FlowTest", 4, "flow123")
            # Wait long enough for round-trip
            await create_timer(10.0).timeout
            print("  After 10s, checking room list...")
            nc.http_list_rooms("en", _on_rooms_after_create)
        else:
            print("  [FAIL] _do_create not available")

func _on_rooms_after_create(result: Dictionary):
    print("\n[STEP 9] Room list after create")
    if result and result.get("success"):
        var rooms = result.get("rooms", [])
        print("  [INFO] Now have " + str(rooms.size()) + " rooms")
        for r in rooms:
            print("    - code=" + str(r.get("code", "?")) +
                " | players=" + str(r.get("playerCount", "?")) +
                " / max=" + str(r.get("maxPlayers", "?")) +
                " | private=" + str(r.get("isPrivate", "?")) +
                " | hasPassword=" + str(r.get("hasPassword", "?")))
        # Find the room we just created
        var found = false
        for r in rooms:
            if r.get("maxPlayers") == 4 and r.get("hasPassword") == true:
                print("  [PASS] Created room with max_players=4 + password found in list")
                flow_ok = true
                found = true
                break
        if not found:
            print("  [FAIL] No room with max_players=4 + password found")

    print("\n========== END FLOW TEST ==========")
    if nc and nc.has_method("disconnect_from_server"):
        nc.disconnect_from_server()
    quit(0 if flow_ok else 1)
