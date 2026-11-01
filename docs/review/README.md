# Ревью и повторное использование контекста

Последние правки персонажа/звука: [REDRAW_AND_RECORDED_AUDIO.md](REDRAW_AND_RECORDED_AUDIO.md). Новый пропорциональный атлас и дыхание, направления после W, проверка 70 пар состояний. Пульс/дождь — записи CC0, происхождение `assets/audio/README.md`; проверка `tools/run_recorded_audio_checks.ps1 [-PackedGame]`. Маска стекла: `tools/run_window_mask_checks.ps1 [-PackedGame]`.

Актуальный художественный проход UI/персонажа: [PRESENTATION_PASS.md](PRESENTATION_PASS.md). Сумка/бумажный архив и компоновка — [CHAPTER_FOLIO_UI.md](CHAPTER_FOLIO_UI.md). Даша использует атлас 64 поз через `dasha_animation.gd`; прежний shader warp больше не используется. Проверки экспортированной версии: `tools/run_presentation_checks.ps1 -PackedGame`.

Первый кадр/пропуск вступления, уведомления целей, бег, процедурные походки, плитка ванной и круговая видимость стен: [NOVEMBER_POLISH.md](NOVEMBER_POLISH.md). `check_november.gd` проверяет экспортированную игру и альфу маски на стыке стен.

Оформление главного меню и всех экранов первой главы: [UI_REDESIGN.md](UI_REDESIGN.md). Общая тема `scripts/noir_ui.gd`, композиция окна `menu_composition.gd`; визуальная проверка `tools/run_ui_checks.ps1 [-PackedGame]`, кадры `images/ui/`.

Установщик/удаление: [INSTALLER.md](INSTALLER.md), воспроизводимый цикл `tools/check_installer.ps1`. В папке установленной игры теперь создаётся ярлык «Удалить Kamdraaa» на штатный `unins000.exe`.

Актуальное начало: [OPENING_FLOW.md](OPENING_FLOW.md). Дверь спальни свободна до таблетки; интро содержит короткий пролёт камеры и контекстные подписи. Старое требование невидимой преграды обучения отменено.

Новая планировка и причинная цепочка исследования: [CHAPTER_1_LEVEL_REBUILD.md](../CHAPTER_1_LEVEL_REBUILD.md). Модули `apartment_story.gd`, `apartment_interior.gd`, `apartment_atmosphere.gd`; физический маршрут проверяется отдельным `tools/run_chapter_checks.ps1 -Route`. Сохранения имеют `layout_revision = 2`.

Пересечения объектов и интерфейс главы после первого плейтеста: [CHAPTER_UI_DEPTH.md](CHAPTER_UI_DEPTH.md). Новые ориентиры HUD, глубинная отрисовка мебели и взаимные коллизии актёров проверяются в `check_chapter.gd` и `capture_chapter.gd`.

**Новая игра теперь запускает главу «Тёмная квартира».** Актуальная карта кода и проверки — [CHAPTER_1_IMPLEMENTATION.md](../CHAPTER_1_IMPLEMENTATION.md). Стенды обучения звонку и двухкомнатного света ниже относятся к оставленному технодемо. Новая глава использует `scripts/chapter_1/`, сохранения v3 и `tools/run_chapter_checks.ps1`; пассивное снижение стресса отключено.

Состояние и физика капель главного меню — [MENU_RAIN.md](MENU_RAIN.md), rain_simulation.gd и menu_glass_rain.gd; check_rain.gd проверяет слияния, сбор по траектории и массу. Старый menu_rain.gdshader теперь рисует только фон, а не капли.

Актуальная звуковая палитра материалов, диалогов и UI — [AUDIO.md](AUDIO.md); check_audio.gd проверяет сигналы, подавление повторов и поверхности шагов. Предыдущий FOOTSTEPS.md описывает раннюю итерацию.

Мягкие шаги и их ритм: [FOOTSTEPS.md](FOOTSTEPS.md), check_footsteps.gd и audio/footsteps.wav.

Начальное обучение звонку, тревоге, обыску кровати и инвентарю — [TUTORIAL.md](TUTORIAL.md), проверки — check_tutorial.gd.

Темп накопления и восстановления паники: [PANIC.md](PANIC.md), проверки — check_panic.gd.

Последующая переделка света, прозрачности стен и фонарика — [LIGHTING.md](LIGHTING.md), проверка рендеринга — check_lighting.gd.

Актуальный результат локального восстановления и проверки Windows — [RESTORATION.md](RESTORATION.md). Команды с /workspace и XDG ниже сохранены как история облачной среды. На Windows запускайте tools/run_review_checks.ps1 с параметром GodotExe; он изолирует тестовые данные в .godot/review-*.

Дата: 2026-10-29 (Asia/Novosibirsk). База: `e5a5f551fcf1cd1b9675e7091ed6d4a802e970a7`.
Ревью исходников, связей сцен, настроек и сборочных инструментов. Это не гарантия отсутствия других дефектов.
После первоначального ревью внесены исправления; детали и ограничения — в FIXES.md.

## Сначала читать в следующей задаче

1. Этот файл и `FINDINGS.md`; затем `python3 tools/review_cache.py`.
2. Код возврата 0 означает совпадение хешей, 1 — список изменённых/добавленных/удалённых файлов. При ошибке инструмента проверить причину, не считать кэш актуальным.
3. Читать только нужные функции из `cache.json` и связанные компоненты ниже. Проверять актуальные строки: номера относятся к базе ревью.
4. Изменение сериализации требует проверки SaveManager, ClueManager, InventoryManager и предметов сцены; изменение ввода — всех обработчиков Input и SettingsManager; изменение паузы — UI, InventoryDialog, PauseMenu и ParanoiaManager.
5. После реального ревью изменений обновить отчёт и лишь затем `python3 tools/review_cache.py --snapshot`. Команда обновляет навигацию, а не подтверждает исправление дефектов. В снимок входят также новые неигнорируемые исходники.

Кэш локален в репозитории и доступен будущим агентам, которые получат эти файлы. Он не создаёт глобальную память и не отменяет проверки изменённого кода. `PROJECT_INDEX.md` и старый Windows-индексатор сохранены; у них нет проверки свежести.

## Карта ответственности

| Компонент | Назначение и связи |
|---|---|
| project.godot | Вход main_menu.tscn; 6 autoload, InputMap, Forward Plus, Jolt |
| main_menu.gd / main_menu.tscn | Новая игра, Continue, загрузка, настройки, shader дождя |
| main.gd / main.tscn | Инициализация комнаты, применение pending save, сброс inventory/paranoia |
| save_manager.gd | JSON user://saves, слоты, применение состояния к существующей сцене или переход из меню |
| clue_manager.gd | 5 улик и 5 дедукций, discovery/connect, сериализация, reset_all_clues |
| inventory_manager.gd | Количества предметов, таблетки, сериализация; сигналы для inventory_dialog |
| settings_manager.gd | user://settings.json, аудио, fullscreen/vsync, InputMap, скорость текста |
| paranoia_manager.gd | Текущий/целевой стресс, decay, BPM и heartbeat; работает на паузе |
| sound_manager.gd | Синтез WAV на старте, Music/SFX, телефонный loop, одноразовые players |
| player.gd | Ускорение, коллизии, шаги, shake, булева блокировка управления |
| quest_item.gd / door.gd | Звонок → диалог → улики → дверь → autosave; tween створки/коллизия |
| interactive_clue.gd | Ближайшая улика, реплики, локальный inspected, связь с ClueManager |
| pills_item.gd | Подбор 3 таблеток, реплика, queue_free предмета |
| dialogue_box.gd | Typewriter, портреты, история, автопереход; cancel тоже испускает finished |
| pause_menu.gd / pause_menu.tscn | Пауза, quicksave/load, слоты, настройки, досье, доска дедукций |
| inventory_dialog.gd / inventory_dialog.tscn | Предметы/использование, блокировка движения без паузы мира |
| flashlight.gd | Input, направление, 2 света, кэш процедурных текстур |
| darkness_anxiety.gd | DarkZone + фонарик → стресс/шёпот/облегчение |
| hud_paranoia.gd / hud_paranoia.tscn | BPM, ECG, стресс, виньетка и shake |
| window_lighting.gd / window_rain_drawer.gd | Процедурное окно, жалюзи, свет машин/неона и капли |
| shaders/menu_rain.gdshader | Процедурный город/дождь/рефракция; нужна отдельная GPU-проверка |
| build_installer.bat/.ps1 / installer.iss | Windows PCK + переименованный редактор Godot + Inno + portable ZIP |
| export_presets.cfg / default_bus_layout.tres | Windows export preset; Master/Music/SFX |
| tools/index_codebase.ps1/.bat | Старый индексатор с абсолютным Windows-путём |

## Проверки

В этой облачной среде установлен Godot 4.7.2. Использовать существующий checkout, без дополнительного worktree.

```bash
source /workspace/.tools/kamdraaa/activate.sh
cd /workspace/kamdraaaGame
godot --headless --path . --editor --import --quit
# Только отдельный чистый каталог пользовательских данных:
mkdir -p /tmp/kamdraaa-review/{data,config,cache}
XDG_DATA_HOME=/tmp/kamdraaa-review/data XDG_CONFIG_HOME=/tmp/kamdraaa-review/config XDG_CACHE_HOME=/tmp/kamdraaa-review/cache godot --headless --path . --script res://docs/review/reproduce.gd
python3 tools/review_cache.py
```

`reproduce.gd` теперь регрессионный набор: exit 0 означает успех всех выполненных проверок, exit 1 — нарушение. Запускайте с новым XDG_DATA_HOME, поскольку проверяется отсутствие выдуманных сохранений. Актуальные изменения и результаты — в [FIXES.md](FIXES.md). Исторические дефекты сохранены в FINDINGS.md.
