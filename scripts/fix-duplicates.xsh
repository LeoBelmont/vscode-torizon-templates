import os
import json
from pathlib import Path

def load_json(path):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return None

def is_duplicate(task_a, task_b):
    return (
        (
            task_a.get("command") == task_b.get("command") and
            task_a.get("type") == task_b.get("type") and
            task_a.get("args") == task_b.get("args") and
            task_a.get("dependsOn") == task_b.get("dependsOn") and
            task_a.get("options", {}).get("env", {}) == task_b.get("options", {}).get("env", {})
        ) or
        task_a.get("label") == task_b.get("label")
    )

def find_duplicates(project_items, common_items):
    return [
        item for item in project_items
        if any(is_duplicate(item, common_item) for common_item in common_items)
    ]

def remove_duplicates(project_items, common_items):
    return [
        item for item in project_items
        if not any(is_duplicate(item, common_item) for common_item in common_items)
    ]

def prompt_yes_no(question):
    while True:
        reply = input(f"{question} [y/n]: ").strip().lower()
        if reply in ("y", "yes"):
            return True
        if reply in ("n", "no"):
            return False

def main():
    root_dir = Path(__file__).resolve().parent.parent
    assets_dir = root_dir / "assets" / "tasks"

    common_tasks_data = load_json(assets_dir / "common.json")
    common_inputs_data = load_json(assets_dir / "inputs.json")
    if not common_tasks_data or not common_inputs_data:
        print("Missing common tasks or inputs JSON. Exiting.")
        return

    common_tasks = common_tasks_data.get("tasks", [])
    common_inputs = common_inputs_data.get("inputs", [])

    for folder in root_dir.iterdir():
        if folder.is_dir():
            vscode_dir = folder / ".vscode"
            tasks_path = vscode_dir / "tasks.json"
            if not tasks_path.exists():
                continue

            project_data = load_json(tasks_path)
            if not project_data:
                continue

            original_tasks = project_data.get("tasks", [])
            original_inputs = project_data.get("inputs", [])

            dup_tasks = find_duplicates(original_tasks, common_tasks)
            dup_inputs = find_duplicates(original_inputs, common_inputs)

            if dup_tasks or dup_inputs:
                print(f"\n🔁 Duplicates found in: {folder.name}")
                for task in dup_tasks:
                    print(f"  🧱 Task: {task.get('label')}")
                for input_item in dup_inputs:
                    print(f"  🔧 Input: {input_item.get('id')}")

                if prompt_yes_no("Do you want to remove the duplicates from this tasks.json?"):
                    project_data["tasks"] = remove_duplicates(original_tasks, common_tasks)
                    project_data["inputs"] = remove_duplicates(original_inputs, common_inputs)
                    with open(tasks_path, "w") as f:
                        json.dump(project_data, f, indent=4)
                    print("✅ Duplicates removed.")
                else:
                    print("⏭️ Skipped.")

    print("\n🏁 Done processing all folders.")

if __name__ == "__main__":
    main()
