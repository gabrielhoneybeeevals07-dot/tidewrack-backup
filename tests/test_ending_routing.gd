extends SceneTree
## Run: godot --headless --path . --script tests/test_ending_routing.gd
var shown_text: String = ""
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1

func _run() -> void:
	var state = root.get_node("GameState")
	var dialogue = root.get_node("DialogueManager")
	dialogue.line_shown.connect(func(_speaker: String, text: String, _choices: Array):
		shown_text = text)
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/endings.json"))
	check(graph.size() == 4, "Expected four ending nodes")
	var cases := [
		[true, false, true, "ending_believer_trusted"],
		[true, false, false, "ending_believer_doubted"],
		[false, true, true, "ending_skeptic_trusted"],
		[false, true, false, "ending_skeptic_doubted"],
	]
	for row in cases:
		for radio in [false, true]:
			state.flags = {"believer": row[0], "skeptic": row[1], "trusted_edith": row[2], "radioed_tom": radio}
			check(state.get_ending_entry() == row[3], "Incorrect ending selection")
			shown_text = ""
			check(dialogue.start_ending(), "Ending failed to start")
			check(shown_text == graph[row[3]]["text"], "Wrong ending text emitted")
			check(not dialogue.start_ending(), "Active ending was replaced")
			check(graph[row[3]]["next"] == null, "Ending must be terminal")
			dialogue.advance()
			check(not dialogue.is_active, "Ending did not finish")
	for invalid in [
		{}, {"believer": true},
		{"believer": false, "skeptic": false, "trusted_edith": true},
		{"believer": true, "skeptic": true, "trusted_edith": false},
		{"believer": "true", "skeptic": false, "trusted_edith": true},
		{"believer": true, "skeptic": false, "trusted_edith": "false"},
	]:
		state.flags = invalid
		check(state.get_ending_entry() == "", "Invalid flags selected an ending")
		check(not dialogue.start_ending(), "Invalid flags started dialogue")
		check(not dialogue.is_active, "Invalid flags left dialogue active")
	state.new_game()
	# Exercise actual flag application through both reread directions.
	for choice in [0, 1, 0]:
		check(dialogue.start("res://data/dialogue/keeper_intro.json", "logbook_choice1"), "Logbook failed to start")
		dialogue.choose(choice)
		check(state.get_flag("skeptic") == (choice == 0), "Skeptic flag stale after reread")
		check(state.get_flag("believer") == (choice == 1), "Believer flag stale after reread")
		dialogue.advance()
		dialogue.advance()
		dialogue.choose(0)
		dialogue.advance()
	print("Ending routing failures: ", failures)
	quit(0 if failures == 0 else 1)
