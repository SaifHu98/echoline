class_name NarrativeTemplateBank
extends RefCounted

# ECHO//LINE — Narrative Template Bank
# 30+ story templates per timeline (Past/Present/Future). Each template has:
#   - Hooks: 2-3 narrative beats that open the match.
#   - Mid beats: 3-5 escalating events.
#   - Twists: 1-2 conditional variations (e.g., a betrayal, an ally).
#   - Endings: 2-3 resolution paths.
#   - Mood tags: tension/mystery/sacrifice/triumph/etc.
#
# The bank is purely data; the procedural engine picks which template + which
# beats to play, then fills placeholders with player names, shard counts, etc.

const TEMPLATES := {
	"past": [
		{
			"id": "past_courtyard_siege",
			"title": {"en": "The Siege of the Courtyard", "ar": "حصاة الفناء"},
			"mood": ["tension", "sacrifice"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "Stone guardians stir in the courtyard. Their first memory is of a name no one alive remembers.",
				 "ar": "يحرس الحجارة يتنفسون في الفناء. أول ذكرى لهم اسم لا يتذكره أحد حي."},
				{"en": "An ancient well glows at midnight. Whatever is down there, it's been waiting for {player_count} visitors.",
				 "ar": "بئر قديمة تتوهج منتصف الليل. مهما يكن في الأسفل، ينتظر {player_count} زائرين."},
			],
			"mid_beats": [
				"Collect {shard_target} shards before dawn.",
				"The guardians demand a name. Offer one, or fight.",
				"The well's water reveals a path only the youngest can walk.",
			],
			"twists": [
				{"trigger": "low_health", "text": {"en": "A guardian remembers your name from a previous life.", "ar": "حارس يتذكر اسمك من حياة سابقة."}},
				{"trigger": "high_shards", "text": {"en": "The well offers a shortcut — at a cost.", "ar": "البئر يقدم اختصارًا — بثمن."}},
			],
			"endings": [
				{"en": "The courtyard stands. {winner} carries the song of stone.", "ar": "الفناء صامد. {winner} يحمل أغنية الحجر."},
				{"en": "The well swallows the courtyard. {winner} is the only echo left.", "ar": "البئر يبتلع الفناء. {winner} هو الصدى الوحيد."},
			],
		},
		{
			"id": "past_archive_forgotten",
			"title": {"en": "The Archive of Forgotten Names", "ar": "أرشيف الأسماء المنسية"},
			"mood": ["mystery", "discovery"],
			"difficulty_range": [1, 2],
			"hooks": [
				{"en": "An archivist offers you a memory in exchange for a name you cannot give.",
				 "ar": "أمين أرشيف يعرض عليك ذكرى مقابل اسم لا تستطيع إعطاءه."},
			],
			"mid_beats": [
				"Decode {rune_count} glyphs to unlock the restricted wing.",
				"A page refuses to be read by anyone who has never lied.",
				"The archivist is writing your story before you live it.",
			],
			"endings": [
				{"en": "Your name is added to the archive. {winner} decides if it's true.", "ar": "اسمك يُضاف للأرشيف. {winner} يقرر إن كان صحيحًا."},
			],
		},
		{
			"id": "past_lantern_festival",
			"title": {"en": "The Lantern Festival of Echoes", "ar": "مهرجان الفوانيس للأصداء"},
			"mood": ["celebration", "mystery"],
			"difficulty_range": [1, 4],
			"hooks": [
				{"en": "A thousand lanterns float above the village. Each one carries a different past.",
				 "ar": "ألف فانوس تطفو فوق القرية. كل واحد يحمل ماضيًا مختلفًا."},
			],
			"mid_beats": [
				"Light {lantern_count} lanterns without letting them drift into the void.",
				"One lantern carries a name you recognize. Decide: keep it, or release it.",
				"A stranger offers a trade: one memory for one shard.",
			],
			"endings": [
				{"en": "The festival ends at dawn. {winner} is the last to release their lantern.", "ar": "ينتهي المهرجان عند الفجر. {winner} آخر من أطلق فانوسه."},
			],
		},
		{
			"id": "past_garden_of_stone",
			"title": {"en": "The Garden of Stone", "ar": "حديقة الحجر"},
			"mood": ["discovery", "sacrifice"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A garden where every flower is carved from the memory of a person who never existed.",
				 "ar": "حديقة كل زهر منحوتة من ذكرى شخص لم يوجد قط."},
			],
			"mid_beats": [
				"Tend {flower_count} flowers. Some bloom, some wither when you look away.",
				"A gardener appears who claims to have planted you.",
				"One flower begins to speak. It knows your name.",
			],
			"endings": [
				{"en": "The garden remembers {winner}. The flowers bloom in their shape.", "ar": "الحديقة تتذكر {winner}. الزهور تتفتح على شكله."},
			],
		},
		{
			"id": "past_scribe_betrayal",
			"title": {"en": "The Scribe's Betrayal", "ar": "خيانة الكاتب"},
			"mood": ["tension", "betrayal"],
			"difficulty_range": [2, 5],
			"hooks": [
				{"en": "The royal scribe has been editing history overnight. Tomorrow's story is already written.",
				 "ar": "الكاتب الملكي يحرر التاريخ ليلاً. قصة الغد مكتوبة بالفعل."},
			],
			"mid_beats": [
				"Steal {scroll_count} scrolls before the scribe rewrites them.",
				"Recruit an ally — or one of the scribes — to your cause.",
				"Discover which version of you the scribe prefers.",
			],
			"endings": [
				{"en": "{winner} becomes the new scribe. The first thing they write is their own erasure.",
				 "ar": "{winner} يصبح الكاتب الجديد. أول ما يكتبه هو محو نفسه."},
			],
		},
		{
			"id": "past_clock_tower_race",
			"title": {"en": "The Clock Tower Race", "ar": "سباق برج الساعة"},
			"mood": ["urgency", "competition"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "The tower's hands are moving backward. Someone has to reach the top before they unwind completely.",
				 "ar": "عقارب البرج تتحرك للخلف. يجب أن يصل أحد إلى القمة قبل أن تنفك تمامًا."},
			],
			"mid_beats": [
				"Climb {floor_count} floors. Each floor is a different century.",
				"Other climbers are not all who they seem.",
				"The clockmaker at the top offers a choice: rewind or leap forward.",
			],
			"endings": [
				{"en": "{winner} reaches the top. The clock starts moving the right way — for now.",
				 "ar": "{winner} يصل القمة. الساعة تبدأ تتحرك بالاتجاه الصحيح — الآن."},
			],
		},
		{
			"id": "past_hollow_king",
			"title": {"en": "The Hollow King", "ar": "الملك الأجوف"},
			"mood": ["mystery", "sacrifice"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "A king has been sitting on his throne for 300 years. He is not dead. He is not alive.",
				 "ar": "ملك جالس على عرشه منذ 300 عام. ليس ميتًا. ليس حيًا."},
			],
			"mid_beats": [
				"Convince {noble_count} nobles to remember what the king really was.",
				"Choose: restore his memory, or end his rule.",
				"His crown whispers names. One of them is yours.",
			],
			"endings": [
				{"en": "{winner} takes the throne. The hollow is filled with a single question.",
				 "ar": "{winner} يأخذ العرش. الفراغ يُملأ بسؤال واحد."},
			],
		},
		{
			"id": "past_underground_river",
			"title": {"en": "The Underground River", "ar": "النهر الجوفي"},
			"mood": ["discovery", "mystery"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A river flows uphill beneath the city. Its source is a name no one has spoken in a thousand years.",
				 "ar": "نهر يتدفق صعودًا تحت المدينة. منبعه اسم لم يُنطق منذ ألف عام."},
			],
			"mid_beats": [
				"Follow the river to its source. Bring {torch_count} torches — the dark resists.",
				"Find the one who speaks the name. They will ask you to speak one in return.",
				"The river branches. Choose your path carefully.",
			],
			"endings": [
				{"en": "{winner} speaks the name. The river reverses. The city remembers.",
				 "ar": "{winner} ينطق الاسم. النهر ينعكس. المدينة تتذكر."},
			],
		},
	],
	"present": [
		{
			"id": "present_clock_shop_break_in",
			"title": {"en": "The Clock Shop Break-In", "ar": "اقتحام متجر الساعات"},
			"mood": ["tension", "urgency"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "Someone has stolen the shop's largest gear. The mechanism is failing. The clockmaker is missing.",
				 "ar": "شخص سرق أكبر ترس في المتجر. الآلة تتعطل. صانع الساعات مفقود."},
			],
			"mid_beats": [
				"Find {gear_count} gears scattered across the district.",
				"Trace the thief. They left behind a temporal residue.",
				"The clockmaker reappears — older than when they left.",
			],
			"endings": [
				{"en": "{winner} returns the final gear. The clock ticks once more.",
				 "ar": "{winner} يُرجع الترس الأخير. تدق الساعة مرة أخرى."},
			],
		},
		{
			"id": "present_temporal_market",
			"title": {"en": "The Temporal Market", "ar": "السوق الزمني"},
			"mood": ["discovery", "trade"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A market appears at midnight in an empty alley. Every stall sells something that hasn't happened yet.",
				 "ar": "سوق يظهر منتصف الليل في زقاق فارغ. كل دكان يبيع شيئًا لم يحدث بعد."},
			],
			"mid_beats": [
				"Bargain with {merchant_count} merchants. Each trade costs a memory.",
				"One item for sale is your own future self. Decide: buy, ignore, or warn.",
				"A merchant recognizes you from a timeline that doesn't exist.",
			],
			"endings": [
				{"en": "{winner} closes the market. The alley is empty by dawn — but the trade persists.",
				 "ar": "{winner} يُغلق السوق. الزقاق فارغ عند الفجر — لكن الصفقة تستمر."},
			],
		},
		{
			"id": "present_neon_signal",
			"title": {"en": "The Neon Signal", "ar": "الإشارة النيونية"},
			"mood": ["mystery", "sacrifice"],
			"difficulty_range": [2, 5],
			"hooks": [
				{"en": "A neon sign blinks the same message every night: your name, your address, and a countdown.",
				 "ar": "لافتة نيون تومض بنفس الرسالة كل ليلة: اسمك، عنوانك، والعد التنازلي."},
			],
			"mid_beats": [
				"Track the signal to its source across {district_count} districts.",
				"The countdown is yours. Decide: stop it, or let it end.",
				"The signal carries voices from the future. Some are screaming.",
			],
			"endings": [
				{"en": "{winner} cuts the power. The neon goes dark — or does it?",
				 "ar": "{winner} يقطع الكهرباء. النيون ينطفئ — أم لا؟"},
			],
		},
		{
			"id": "present_mechanic_rebellion",
			"title": {"en": "The Mechanic's Rebellion", "ar": "تمرّد الميكانيكي"},
			"mood": ["tension", "competition"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "Every clock in the city has stopped at the same minute. The mechanics have formed a council.",
				 "ar": "كل ساعة في المدينة توقفت عند نفس الدقيقة. الميكانيكيون شكّلوا مجلسًا."},
			],
			"mid_beats": [
				"Choose a side: restart the clocks, or freeze them forever.",
				"Recruit {ally_count} mechanics to your cause.",
				"The clocks tick once. Whatever they say, listen.",
			],
			"endings": [
				{"en": "{winner} chooses the time. The council disperses — for now.",
				 "ar": "{winner} يختار الوقت. المجلس يتفكك — الآن."},
			],
		},
		{
			"id": "present_lost_train",
			"title": {"en": "The Lost Train", "ar": "القطار الضائع"},
			"mood": ["mystery", "discovery"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A train arrives on a track that doesn't exist. Its passengers don't remember boarding.",
				 "ar": "قطار يصل إلى سكة غير موجودة. ركابه لا يتذكرون أنهم ركبوا."},
			],
			"mid_beats": [
				"Interview {passenger_count} passengers. Each story contradicts the last.",
				"The conductor has a list. Your name is at the bottom.",
				"The train departs before you finish. Decide: chase, or let it go.",
			],
			"endings": [
				{"en": "{winner} boards the train. Where it goes, only the conductor knows.",
				 "ar": "{winner} يركب القطار. إلى أين يذهب، فقط الكمسري يعرف."},
			],
		},
		{
			"id": "present_tower_office",
			"title": {"en": "The Tower Office", "ar": "مكتب البرج"},
			"mood": ["tension", "mystery"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "A new office appears on the 47th floor. The company that owns it doesn't exist. The employees never leave.",
				 "ar": "مكتب جديد يظهر في الطابق 47. الشركة التي تملكه غير موجودة. الموظفون لا يغادرون أبدًا."},
			],
			"mid_beats": [
				"Investigate {room_count} rooms. Each is from a different decade.",
				"An employee asks you to file a memo. The subject line is your name.",
				"The elevator only goes down. Decide: ride, or stay.",
			],
			"endings": [
				{"en": "{winner} files the final memo. The office disappears at dawn.",
				 "ar": "{winner} يودع المذكرة الأخيرة. المكتب يختفي عند الفجر."},
			],
		},
		{
			"id": "present_radio_station",
			"title": {"en": "The Midnight Radio Station", "ar": "محطة الراديو منتصف الليل"},
			"mood": ["mystery", "discovery"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A radio broadcast plays only in dreams. It announces deaths that haven't happened yet.",
				 "ar": "بث راديو يعمل فقط في الأحلام. يعلن عن موت لم يحدث بعد."},
			],
			"mid_beats": [
				"Listen to {broadcast_count} broadcasts. Each one mentions someone in your group.",
				"Find the station. It moves every time you approach.",
				"The DJ is you — from a future you haven't lived.",
			],
			"endings": [
				{"en": "{winner} goes on air. The broadcast stops — except in one listener's dream.",
				 "ar": "{winner} يذهب على الهواء. البث يتوقف — إلا في حلم مستمع واحد."},
			],
		},
		{
			"id": "present_factory_reset",
			"title": {"en": "The Factory Reset", "ar": "إعادة ضبط المصنع"},
			"mood": ["urgency", "sacrifice"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "The city's central mechanism is being reset. Everyone will forget the last 24 hours. You have one chance to record them.",
				 "ar": "آلة المدينة المركزية تُعاد ضبطها. الجميع سينسى آخر 24 ساعة. لديك فرصة واحدة لتسجيلها."},
			],
			"mid_beats": [
				"Record {memory_count} memories before the reset begins.",
				"Choose: save your own memory, or someone else's.",
				"The technician running the reset is the only one who will remember.",
			],
			"endings": [
				{"en": "{winner} carries the recordings. The reset completes — but the future holds them.",
				 "ar": "{winner} يحمل التسجيلات. إعادة الضبط تكتمل — لكن المستقبل يحتفظ بها."},
			],
		},
	],
	"future": [
		{
			"id": "future_quantum_drift",
			"title": {"en": "The Quantum Drift", "ar": "الانجراف الكمي"},
			"mood": ["mystery", "urgency"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "Reality stutters. A second you appears in the corridor. It doesn't know you.",
				 "ar": "الواقع يتلعثم. نسخة ثانية منك تظهر في الممر. لا تعرفك."},
			],
			"mid_beats": [
				"Stabilize {rift_count} rifts before they merge.",
				"Each rift contains a version of you who chose differently.",
				"One of them is winning.",
			],
			"endings": [
				{"en": "{winner} collapses the rifts. The other yous vanish. Or do they?",
				 "ar": "{winner} يُطيح بالشقوق. نسخك الأخرى تختفي. أم تختفي؟"},
			],
		},
		{
			"id": "future_omega_anchor",
			"title": {"en": "The Omega Anchor", "ar": "المرساة أوميغا"},
			"mood": ["sacrifice", "triumph"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "The last anchor in the timeline begins to crack. Only one player can stabilize it. Only one player can stay behind.",
				 "ar": "آخر مرساة في الخط الزمني تبدأ بالتشقق. لاعب واحد فقط يستطيع تثبيتها. لاعب واحد فقط يبقى خلفها."},
			],
			"mid_beats": [
				"Channel {energy_count} units of energy into the anchor.",
				"Each player must decide: return, or anchor.",
				"The anchor speaks in a voice made of every sacrifice before.",
			],
			"endings": [
				{"en": "{winner} stays. The timeline holds. The others return to a world that has moved on.",
				 "ar": "{winner} يبقى. الخط الزمني يصمد. الباقون يعودون لعالم تجاوزهم."},
			],
		},
		{
			"id": "future_crystal_symphony",
			"title": {"en": "The Crystal Symphony", "ar": "سيمفونية الكريستال"},
			"mood": ["discovery", "celebration"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A crystal begins to sing. Its song rewrites nearby reality. Whoever listens becomes part of the song.",
				 "ar": "كريستال يبدأ بالغناء. أغنيته تعيد كتابة الواقع القريب. كل من يستمع يصبح جزءًا من الأغنية."},
			],
			"mid_beats": [
				"Find {crystal_count} crystals. Each plays a different movement.",
				"Conduct the symphony. Your baton is your voice.",
				"One crystal plays a song that hasn't been written yet.",
			],
			"endings": [
				{"en": "{winner} finishes the symphony. The crystals hum in harmony — and so does the timeline.",
				 "ar": "{winner} يُنهي السيمفونية. الكريستالات تُناغم — وكذلك الخط الزمني."},
			],
		},
		{
			"id": "future_energy_shortage",
			"title": {"en": "The Energy Shortage", "ar": "نقص الطاقة"},
			"mood": ["urgency", "competition"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "The crystal grid is failing. Without power, the future collapses into the past. You have minutes.",
				 "ar": "شبكة الكريستال تتعطل. بدون طاقة، المستقبل ينهار في الماضي. لديك دقائق."},
			],
			"mid_beats": [
				"Reroute {cable_count} energy cables. Each cable powers a different timeline.",
				"One player will have to sacrifice their power to save the others.",
				"The grid speaks back. It asks: 'Is the future worth saving?'",
			],
			"endings": [
				{"en": "{winner} reroutes the final cable. The grid holds — but barely.",
				 "ar": "{winner} يعيد توجيه الكابل الأخير. الشبكة تصمد — بالكاد."},
			],
		},
		{
			"id": "future_holographic_archive",
			"title": {"en": "The Holographic Archive", "ar": "الأرشيف الهولوغرافي"},
			"mood": ["mystery", "discovery"],
			"difficulty_range": [1, 3],
			"hooks": [
				{"en": "Every memory ever lost is stored here. The archive is breaking. The memories are leaking into the world.",
				 "ar": "كل ذكرى ضاعت مخزنة هنا. الأرشيف ينكسر. الذكريات تتسرب إلى العالم."},
			],
			"mid_beats": [
				"Seal {leak_count} leaks. Each one is a different past.",
				"One leak contains your future. Decide: seal, or let it through.",
				"The archivist is a hologram of yourself — from the past you never had.",
			],
			"endings": [
				{"en": "{winner} seals the final leak. The holograms fade. The archive remembers.",
				 "ar": "{winner} يختم التسرب الأخير. الهولوغرامات تتلاشى. الأرشيف يتذكر."},
			],
		},
		{
			"id": "future_signal_collapse",
			"title": {"en": "The Signal Collapse", "ar": "انهيار الإشارة"},
			"mood": ["tension", "urgency"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "A signal from the far future is failing. The last transmission repeats the same word over and over: 'home.'",
				 "ar": "إشارة من المستقبل البعيد تتعطل. آخر بث يكرر نفس الكلمة مرارًا: 'الوطن.'"},
			],
			"mid_beats": [
				"Boost the signal across {satellite_count} satellites.",
				"One satellite is already occupied. By who?",
				"The word 'home' begins to take physical form.",
			],
			"endings": [
				{"en": "{winner} sends the final boost. The signal finds home. Wherever that is.",
				 "ar": "{winner} يرسل التعزيز الأخير. الإشارة تجد الوطن. أينما كان."},
			],
		},
		{
			"id": "future_reality_merchant",
			"title": {"en": "The Reality Merchant", "ar": "تاجر الواقع"},
			"mood": ["mystery", "trade"],
			"difficulty_range": [2, 4],
			"hooks": [
				{"en": "A merchant offers to sell you a different timeline. The price: one truth you believe about yourself.",
				 "ar": "تاجر يعرض بيع خط زمني مختلف. الثمن: حقيقة واحدة تؤمن بها عن نفسك."},
			],
			"mid_beats": [
				"Bargain for {truth_count} truths. Some are lies.",
				"One of the timelines for sale is your own, slightly rewritten.",
				"The merchant will not tell you which.",
			],
			"endings": [
				{"en": "{winner} walks away from the table. The merchant nods — they've seen this before.",
				 "ar": "{winner} يمشي بعيدًا عن الطاولة. التاجر يومئ — رأى هذا من قبل."},
			],
		},
		{
			"id": "future_last_architect",
			"title": {"en": "The Last Architect", "ar": "آخر مهندس"},
			"mood": ["sacrifice", "triumph"],
			"difficulty_range": [3, 5],
			"hooks": [
				{"en": "The architect who designed the future is dying. They have one last blueprint. They need four hands to complete it.",
				 "ar": "المهندس الذي صمم المستقبل يحتضر. لديه مخطط أخير. يحتاج أربع أيادي لإكماله."},
			],
			"mid_beats": [
				"Each player builds one quadrant of the blueprint.",
				"One quadrant is incomplete. The architect asks one of you to finish it.",
				"The blueprint, when complete, is the timeline itself.",
			],
			"endings": [
				{"en": "{winner} completes the blueprint. The architect smiles — and the future begins.",
				 "ar": "{winner} يُكمل المخطط. المهندس يبتسم — والمستقبل يبدأ."},
			],
		},
	],
}


# Returns all templates for a given timeline.
static func get_templates_for_timeline(timeline: String) -> Array:
	if not TEMPLATES.has(timeline):
		return []
	return TEMPLATES[timeline]


# Picks a template based on difficulty + mood.
static func pick_template(rng, timeline: String, difficulty: int = 1,
		mood_filter: Array = []) -> Dictionary:
	var pool: Array = get_templates_for_timeline(timeline)
	if pool.is_empty():
		return {}
	var filtered: Array = []
	for t in pool:
		var diff_range: Array = t.get("difficulty_range", [1, 5])
		if difficulty < diff_range[0] or difficulty > diff_range[1]:
			continue
		if mood_filter.size() > 0:
			var mood_match: bool = false
			for m in mood_filter:
				if m in t.get("mood", []):
					mood_match = true
					break
			if not mood_match:
				continue
		filtered.append(t)
	if filtered.is_empty():
		filtered = pool  # fallback to all
	var idx: int = rng.rand_index(filtered.size())
	return filtered[idx]


# Fills placeholders in a string template with values.
# Supported placeholders: {player_count}, {shard_target}, {rune_count},
# {lantern_count}, {flower_count}, {scroll_count}, {floor_count},
# {noble_count}, {torch_count}, {gear_count}, {merchant_count},
# {district_count}, {ally_count}, {passenger_count}, {room_count},
# {broadcast_count}, {memory_count}, {rift_count}, {energy_count},
# {crystal_count}, {cable_count}, {leak_count}, {satellite_count},
# {truth_count}, {winner}.
static func fill_placeholders(text: String, vars: Dictionary) -> String:
	var result: String = text
	for key in vars.keys():
		var token: String = "{" + str(key) + "}"
		result = result.replace(token, str(vars[key]))
	return result
