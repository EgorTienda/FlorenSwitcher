script_name("FlorenSwitcher")
script_author("Egor Tienda")
script_version("1.6")

require "lib.moonloader"
local inicfg = require "inicfg"
local memory = require "memory"

-- Конфигурация по умолчанию
local defaultConfig = {
    settings = {
        time_command = "time",
        weather_command = "weather",
        reset_command = "reset",
        maxhour = 24,
        maxweathervalue = 45,
        default_hour = -1,     -- -1 означает, что по умолчанию лок выключен
        default_weather = -1   -- -1 означает, что по умолчанию лок выключен
    }
}

local cfg = {}
local config_name = "florenswitcher.ini"
-- Полный путь к файлу конфигурации в папке config/
local config_full_path = getWorkingDirectory() .. "\\config\\" .. config_name

-- Переменные для сохранения текущего принудительного состояния (-1 = выключено)
local locked_hour = -1
local locked_minute = 0
local locked_weather = -1

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end


    -- Проверка и создание папки config, если её нет
    local config_dir = getWorkingDirectory() .. "\\config"
    if not doesDirectoryExist(config_dir) then
        createDirectory(config_dir)
    end

    -- Загрузка или создание INI-файла
    cfg = inicfg.load(defaultConfig, config_name)
    if not cfg then
        cfg = defaultConfig
        local save_status = inicfg.save(defaultConfig, config_name)
        if save_status then
        else
        end
    else
    end

    -- Читаем сохраненные параметры времени и погоды из конфига при запуске
    if cfg.settings.default_hour and cfg.settings.default_hour >= 0 then
        locked_hour = cfg.settings.default_hour
    end
    if cfg.settings.default_weather and cfg.settings.default_weather >= 0 then
        locked_weather = cfg.settings.default_weather
    end

    -- Вывод сообщений в чат
    sampAddChatMessage("{73b4ff}[FlorenSwitcher]{ffffff} Скрипт запущен.", -1)
    sampAddChatMessage("{73b4ff}[FlorenSwitcher]{ffffff} Репозиторий GitHub: https://github.com/EgorTienda/FlorenSwitcher", -1)

    sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Автор скрипта: Egor Tienda. Команды: /%s, /%s, /%s", 
        cfg.settings.time_command, cfg.settings.weather_command, cfg.settings.reset_command or "reset"), -1)

    -- Регистрация команд из конфига
    sampRegisterChatCommand(cfg.settings.weather_command, cmd_weather)
    sampRegisterChatCommand(cfg.settings.time_command, cmd_time)
    sampRegisterChatCommand(cfg.settings.reset_command or "reset", cmd_reset)

    -- Фоновый поток для постоянного удержания зафиксированного времени и погоды
    lua_thread.create(function()
        while true do
            wait(0)
            if locked_hour ~= -1 then
                setTimeOfDay(locked_hour, locked_minute)
            end
            if locked_weather ~= -1 then
                memory.setint32(0xC81320, locked_weather, true)
                memory.setint32(0xC81324, locked_weather, true)
            end
        end
    end)

    while true do
        wait(0)
    end
end

-- Обработчик команды погоды
function cmd_weather(arg)
    local maxWeather = cfg.settings.maxweathervalue or 45
    if arg and arg:match("^%d+$") then
        local weatherId = tonumber(arg)
        if weatherId >= 0 and weatherId <= maxWeather then
            locked_weather = weatherId
            
            cfg.settings.default_weather = weatherId
            local result = inicfg.save(cfg, config_name)
            if result then
                sampfuncsLog("[FlorenSwitcher] Погода " .. weatherId .. " сохранена в конфиг.")
            else
                sampfuncsLog("[FlorenSwitcher] ОШИБКА сохранения погоды в конфиг!")
            end

            memory.setint32(0xC81320, weatherId, true)
            memory.setint32(0xC81324, weatherId, true)
            sampAddChatMessage("{73b4ff}[FlorenSwitcher]{ffffff} Погода изменена и сохранена: " .. weatherId, -1)
        else
            sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Ошибка: ID погоды должен быть от 0 до %d!", maxWeather), -1)
        end
    else
        sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Использование: /%s <0-%d>", cfg.settings.weather_command, maxWeather), -1)
    end
end

-- Обработчик команды времени
function cmd_time(arg)
    local maxHour = cfg.settings.maxhour or 24
    if arg and arg:match("^%d+$") then
        local hour = tonumber(arg)
        if hour >= 0 and hour <= maxHour then
            if hour == 24 then hour = 0 end
            
            locked_hour = hour
            locked_minute = 0
            
            cfg.settings.default_hour = hour
            local result = inicfg.save(cfg, config_name)
            if result then
                sampfuncsLog("[FlorenSwitcher] Час " .. hour .. " сохранен в конфиг.")
            else
                sampfuncsLog("[FlorenSwitcher] ОШИБКА сохранения времени в конфиг!")
            end

            setTimeOfDay(hour, 0)
            sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Время изменено и сохранено: %02d:00", hour), -1)
        else
            sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Ошибка: час должен быть в диапазоне от 0 до %d!", maxHour), -1)
        end
    else
        sampAddChatMessage(string.format("{73b4ff}[FlorenSwitcher]{ffffff} Использование: /%s <0-%d>", cfg.settings.time_command, maxHour), -1)
    end
end

-- Обработчик команды /reset (удаление конфига и сброс фиксации)
function cmd_reset()
    locked_hour = -1
    locked_weather = -1
    
    cfg = defaultConfig

    if doesFileExist(config_full_path) then
        local success = os.remove(config_full_path)
        if success then
            sampfuncsLog("[FlorenSwitcher] Файл конфигурации успешно удален через /reset.")
        else
            sampfuncsLog("[FlorenSwitcher] ОШИБКА: Не удалось удалить файл конфигурации!")
        end
    else
        sampfuncsLog("[FlorenSwitcher] Файл конфигурации не найден при попытке удаления.")
    end
    
    sampAddChatMessage("{73b4ff}[FlorenSwitcher]{ffffff} Конфигурация удалена. Настройки сброшены до серверных.", -1)
end
