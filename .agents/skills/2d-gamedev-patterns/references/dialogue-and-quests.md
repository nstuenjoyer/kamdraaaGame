# Dialogue & Quest System Architecture

## 1. Dialogue Data Model (`Resource`)
Using Godot `Resource` files allows designing dialogues directly in the inspector or loading from JSON:

```gdscript
class_name DialogueEntry
extends Resource

@export var speaker_name: String
@export_multiline var text: String
@export var portrait: Texture2D
@export var voice_clip: AudioStream
```

## 2. Quest Manager Pattern
Track objectives and progress cleanly with enum states:

```gdscript
class_name QuestManager
extends Node

enum QuestState { NOT_STARTED, IN_PROGRESS, COMPLETED, FAILED }

var quests: Dictionary = {
    "answer_phone": {
        "title": "Звонок из прошлого",
        "description": "Подойти к телефону и поднять трубку",
        "state": QuestState.IN_PROGRESS
    },
    "escape_apartment": {
        "title": "Выход на улицу",
        "description": "Покинуть квартиру через открытую дверь",
        "state": QuestState.NOT_STARTED
    }
}

signal quest_updated(quest_id: String, new_state: QuestState)

func complete_quest(quest_id: String) -> void:
    if quests.has(quest_id) and quests[quest_id]["state"] == QuestState.IN_PROGRESS:
        quests[quest_id]["state"] = QuestState.COMPLETED
        quest_updated.emit(quest_id, QuestState.COMPLETED)
        
        # Unlock next quest if chained
        if quest_id == "answer_phone":
            start_quest("escape_apartment")

func start_quest(quest_id: String) -> void:
    if quests.has(quest_id) and quests[quest_id]["state"] == QuestState.NOT_STARTED:
        quests[quest_id]["state"] = QuestState.IN_PROGRESS
        quest_updated.emit(quest_id, QuestState.IN_PROGRESS)
```
