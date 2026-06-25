extends RefCounted
class_name Lines
## All flavour text in one place so it's trivial to pour in more. Two voices:
##   princess_say()  — the (increasingly suspicious) Princess
##   squire_say()    — your snide inner villain / narrator
## Pools are grouped by tone (gag / rude / fun) and by event. Pull with Lines.pick().

static func pick(pool: Array) -> String:
	return pool[randi() % pool.size()] if pool.size() > 0 else ""

# --- death epilogues for a NON-queen death (you died to your own chaos, the
#     horde, or a stray trap — not at the Princess's hand). Shown on the loss screen.
const POINTLESS_DEATH := [
	"Not even the Princess noticed.",
	"Slain mid-scheme. How embarrassing.",
	"You died doing chores.",
	"All that treason, undone by a stray rock.",
	"The horde you befriended forgot whose side they were on.",
	"Hoist by your own petard. Literally.",
]

# --- general squire barks (ambient personality) -----------------------------
const GAG := [
	"Whoopsie. Big whoopsie.",
	"That was DEFINITELY an accident.",
	"I have no idea how that got there.",
	"Working as intended. My intent.",
]
const RUDE := [
	"Eat dirt, Your Highness.",
	"Cry about it, princess.",
	"Skill issue, milady.",
	"Womp womp. Royally.",
]
const FUN := [
	"Chaos? In MY kingdom? Always.",
	"Ah, the smell of treason in the morning.",
	"Loyalty is so last season.",
	"Sabotage is a love language.",
]

# --- plane / airship crash --------------------------------------------------
const PLANE_SQUIRE := [
	"Is that... a PLANE?! (it was me. I did this.)",
	"Incoming! ...allegedly.",
	"Special delivery, Your Majesty!",
	"I ordered the large.",
	"Cleared for landing. On her face.",
	"Terms and conditions of the sky apply.",
]
const PLANE_PRINCESS := [
	"What in the seven realms is THAT?!",
	"That is NOT in the budget!",
	"SQUIRE?! Explain the sky!",
	"WHO APPROVED AVIATION?!",
]

# --- peasant revolt ---------------------------------------------------------
const PROTEST_SQUIRE := [
	"The people have... feedback.",
	"Funny how a few rumors spread.",
	"Tax the rich! (her, specifically.)",
	"Grassroots movement. I planted it.",
]
const PROTEST_PRINCESS := [
	"My loyal subjects?! Why?!",
	"Guards! ...where are my guards?",
	"This is a misunderstanding, peasants!",
]

# --- monster infighting -----------------------------------------------------
const INFIGHT_SQUIRE := [
	"Did someone start a rumor? (me. it was me.)",
	"Fight amongst yourselves, lads.",
	"Drama in the horde. Delicious.",
]

# --- the "67" gag -----------------------------------------------------------
const SWARM67_SQUIRE := [
	"6... 7. Perfectly balanced.",
	"You asked for it. Sixty. Seven.",
	"The prophecy is real.",
]

# --- squire schemes (the Q-triggered, suspicion-costing chaos) ---------------
const SCHEME_SQUIRE := [
	"Time to stir the pot.",
	"Let's make some noise.",
	"She'll never suspect a thing. (she will.)",
]

# --- moving traps (ambient chaos) -------------------------------------------
const TRAP_SQUIRE := [
	"Mind the gap. And the spikes. And everything.",
	"The floor is now lava-adjacent.",
	"I rented this room from a goblin.",
	"Dodge or don't. I'm not your dad.",
]

# --- between-wave banter (story beats / context; paired by index) ------------
## INTERLUDE_PRINCESS[i] is her line; INTERLUDE_SQUIRE[i] is your snide reply.
## Keep the two arrays the SAME length so a random index works for both.
const INTERLUDE_PRINCESS := [
	"Another wave repelled! You bring me the finest supplies, squire.",
	"We make a wonderful team, you and I.",
	"Odd... these monsters seem to know our every move.",
	"My strength wanes between battles. Have I been overexerting?",
	"Stay close, loyal squire. The whole realm depends on us.",
	"You've served the crown so faithfully. I shall reward you.",
]
const INTERLUDE_SQUIRE := [
	"Only the finest, milady. Hand-poisoned with care.",
	"A wonderful team. One of us is even winning.",
	"Know our moves? Couldn't imagine how. (I told them everything.)",
	"Overexerting. Yes. Let's go with that, Your Highness.",
	"The realm depends on me, all right. Just not the way you think.",
	"Reward me? Oh, I'm counting on the throne.",
]

# --- escalating Princess suspicion (paced by Game._run_suspicion_barks) -------
## DOUBT stage (~40%+): she voices unease but hasn't turned yet.
const DOUBT_PRINCESS := [
	"Squire... why aren't you fighting beside me?",
	"These monsters knew our plans. How?",
	"You hang back so often lately.",
	"My strength keeps slipping. Curious.",
	"You flinch every time I'm struck. Why?",
]
## FRIENDLY_FIRE stage (~70%+): her attacks can now catch you, and she says so.
const ACCUSE_PRINCESS := [
	"Stay out of my reach if you value your skin.",
	"Mind the blast, squire — I won't aim around you.",
	"I'm watching you now. Closely.",
	"One more 'accident' and we'll have words.",
]

# --- the Angel of Retribution (divine punishment for serial sabotage) --------
const ANGEL_SQUIRE := [
	"I can explain. (I cannot.)",
	"Not the smiting! ANYTHING but the smiting!",
	"Snitches get... lasered, apparently.",
	"Okay, the big guy upstairs is mad mad.",
]
const ANGEL_PRINCESS := [
	"DIVINE JUSTICE! The heavens see you, squire!",
	"At LAST, a witness with standards!",
	"Smite him! ...respectfully!",
]
