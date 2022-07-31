# TSLPatcher
A repository for the current state of the TSLPatcher mod installer for Star Wars: Knights of the Old Republic 1 and 2.

## TSLPatcherCLI
TSLPatcherCLI provides the same functionality as TSLPatcher, but without the GUI. This is intended to be used for mod management tools.

### Setup
For Windows 10:
* Install Strawberry Perl v5.16.3.1 (https://strawberryperl.com/releases.html)
* Install dependencies by opening the Command Prompt as an administrator and running: `cpan install pp && cpan install experimental && cpan install Config::IniMan`

### Usage
TSLPatcherCLI takes three arguments:
1. swkotorDirectory - the game directory that swkotor.exe is in.
2. modDirectory - the extracted mod directory that TSLPatcher.exe and the tslpatchdata directory are in.
3. installOption (optional) - the install option only for mods that have a tslpatcher/namespaces.ini file that matches the array index of the options under `[Namespaces]`. If there is no tslpatcher/namespaces.ini file then don't inclue this. In the example below the `installOption` for Vanilla would be `0` and Ord Mantell would be `1`.
```
[Namespaces]
Namespace1=Vanilla
Namespace2=Ord Mantell
```

Run the script locally: `perl TSLPatcherCLI.pl <swkotorDirectory> <modDirectory> <installOption>`
* Example: `perl TSLPatcherCLI.pl "C:\Program Files (x86)\Steam\steamapps\common\swkotor" "C:\Mods\K1 Galaxy Map Fix Pack" 0`

Build the script to .exe: `pp -o TSLPatcherCLI.exe TSLPatcherCLI.pl`