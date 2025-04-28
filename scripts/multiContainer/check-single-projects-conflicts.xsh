#!/usr/bin/env xonsh

import argparse
from pathlib import Path
import json
import yaml
import os
import glob

parser = argparse.ArgumentParser()
parser.add_argument('--accept-all', action='store_true')
args = parser.parse_args()

param_accept_all = args.accept_all

script_dir = os.path.dirname(__file__)
workspace_dir = os.path.abspath(os.path.join(script_dir, ".."))

workspace_file = glob.glob("./*.code-workspace")[0]
with open(workspace_file, 'r') as f:
    obj_code_workspaces = json.load(f)

metadata_path = Path(".conf/metadata.json")
project_name = None

if metadata_path.exists():
    with metadata_path.open() as f:
        obj_metadata = json.load(f)
    project_name = obj_metadata.get("multiContainerProjectName", None)

def add_value(lst, name, setting_name, value):
    if value != "":
        lst.append({
            "name": name,
            "settingName": setting_name,
            "settingValue": int(value)
        })

def fix_duplicates(settings_list):
    duplicated = False
    list_sorted = sorted(settings_list, key=lambda x: x["settingValue"])
    i = 0
    while i < len(list_sorted) - 1:
        if list_sorted[i]["settingValue"] == list_sorted[i+1]["settingValue"]:
            duplicated = True
            j = i + 1
            while j+1 < len(list_sorted) and abs(list_sorted[j+1]["settingValue"] - list_sorted[j]["settingValue"]) < 2:
                j += 1
            new_setting_value = list_sorted[j]["settingValue"] + 1
            print(f"\033[33m {list_sorted[i]['name']} {list_sorted[i]['settingName']} and {list_sorted[i+1]['name']} {list_sorted[i+1]['settingName']} have the same value {list_sorted[i]['settingValue']} -> new suggested value for {list_sorted[i]['name']} {list_sorted[i]['settingName']}: {new_setting_value}\033[0m")
            list_sorted[i]["settingValue"] = new_setting_value
            list_sorted = sorted(list_sorted, key=lambda x: x["settingValue"])
        else:
            i += 1
    return list_sorted, duplicated

with open("./docker-compose.yml", 'r') as f:
    docker_compose_yaml = yaml.safe_load(f)

docker_compose_ports = []

for service_name, service_value in docker_compose_yaml.get('services', {}).items():
    for port in service_value.get('ports', []):
        host_port = port.split(":")[0]
        try:
            host_num = int(host_port)
            if any(d["settingValue"] == host_num for d in docker_compose_ports):
                print(f"{host_port} host port is duplicated on docker-compose.yml")
            else:
                add_value(docker_compose_ports, project_name, "yaml_docker_compose_port", host_port)
        except ValueError:
            pass

debug_ports_settings = []
wait_sync_settings = []

for item in obj_code_workspaces["folders"]:
    project_name = item["path"]
    if project_name != ".":
        settings_path = os.path.join(project_name, ".vscode", "settings.json")
        with open(settings_path, 'r') as f:
            project_settings = json.load(f)

        add_value(debug_ports_settings, project_name, "torizon_debug_ssh_port", project_settings.get("torizon_debug_ssh_port", ""))
        add_value(debug_ports_settings, project_name, "torizon_debug_port1", project_settings.get("torizon_debug_port1", ""))
        add_value(debug_ports_settings, project_name, "torizon_debug_port2", project_settings.get("torizon_debug_port2", ""))
        add_value(debug_ports_settings, project_name, "torizon_debug_port3", project_settings.get("torizon_debug_port3", ""))
        add_value(wait_sync_settings, project_name, "wait_sync", project_settings.get("wait_sync", ""))

debug_ports_settings += docker_compose_ports

# -- Check and fix duplicates
new_debug_ports_settings, debug_port_duplicated = ([], False)
new_wait_sync_settings, wait_sync_duplicated = ([], False)

if len(debug_ports_settings) > 1:
    new_debug_ports_settings, debug_port_duplicated = fix_duplicates(debug_ports_settings)

if len(wait_sync_settings) > 1:
    new_wait_sync_settings, wait_sync_duplicated = fix_duplicates(wait_sync_settings)

# -- Apply fixes
if debug_port_duplicated or wait_sync_duplicated:
    if param_accept_all:
        update_confirm = 'y'
    else:
        update_confirm = input("Do you want to update the debug ports and wait_syncs to the suggested values? <y/N> ")

    if update_confirm.lower() == 'y':
        for item in obj_code_workspaces["folders"]:
            project_name = item["path"]
            if project_name != ".":
                settings_path = os.path.join(project_name, ".vscode", "settings.json")
                with open(settings_path, 'r') as f:
                    project_settings = json.load(f)

                for setting in new_debug_ports_settings:
                    if setting["name"] == project_name:
                        setting_name = setting["settingName"]
                        project_settings[setting_name] = str(setting["settingValue"])

                for setting in new_wait_sync_settings:
                    if setting["name"] == project_name:
                        setting_name = setting["settingName"]
                        project_settings[setting_name] = str(setting["settingValue"])

                with open(settings_path, 'w') as f:
                    json.dump(project_settings, f, indent=4)

        print("\033[32m✅ Debug port and wait_sync settings conflicts solved (new setting values applied)\033[0m")
    else:
        print("\033[31m❌ Please solve debug port and wait_sync settings conflicts before running the commands\033[0m")
else:
    print("\033[32m✅ No debug port or wait_sync settings conflicts\033[0m")

popd

