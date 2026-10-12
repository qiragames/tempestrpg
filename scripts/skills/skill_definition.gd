extends Resource
## Data shared by analysis, the skill book, and future hotbar presentation.

@export var id: StringName
@export var display_name: String
@export_enum("Common", "Extra", "Unique", "Ultimate") var tier: String = "Common"
@export_multiline var description: String
@export var damage: int = 20
@export var magicule_cost: float = 12.0
@export var cooldown: float = 0.8
## Dispatch key for activation; see SkillCatalogue.EFFECTS. Unknown effects never execute.
@export var effect: StringName = &"strike"
