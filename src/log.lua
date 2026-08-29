--[[
    TempleEx Logger
    Simple logging with levels, file output, and in-game console integration
]]

local Log = {}
Log.__index = Log

local Levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

local LevelNames = { "DEBUG", "INFO", "WARN", "ERROR", "FATAL" }

local currentLevel = Levels.INFO
local logFile = nil
local logBuffer = {}
local maxBuffer = 500

function Log.init(config)
    config = config or {}
    currentLevel = Levels[string.upper(config.level or "INFO")] or Levels.INFO
    logFile = config.file
    if logFile then
        -- Ensure log directory exists
        local Executor = require(script.Parent.executor)
        local dir = logFile:match("^(.+)[/\\][^/\\]+$")
        if dir then
            pcall(Executor.fs_mkdir, dir)
        end
    end
end

function Log.setLevel(level)
    currentLevel = Levels[string.upper(level)] or Levels.INFO
end

local function writeToFile(msg)
    if not logFile then return end
    local Executor = require(script.Parent.executor)
    pcall(Executor.fs_append, logFile, msg .. "\n")
end

local function format(level, ...)
    local args = {...}
    local parts = {}
    for i = 1, #args do
        local v = args[i]
        if type(v) == "table" then
            local ok, json = pcall(function() return game:GetService("HttpService"):JSONEncode(v) end)
            parts[i] = ok and json or tostring(v)
        else
            parts[i] = tostring(v)
        end
    end
    local timestamp = os.date("%H:%M:%S")
    return string.format("[%s] [%s] %s", timestamp, LevelNames[level], table.concat(parts, " "))
end

local function log(level, ...)
    if level < currentLevel then return end
    local msg = format(level, ...)
    -- Buffer
    table.insert(logBuffer, msg)
    if #logBuffer > maxBuffer then
        table.remove(logBuffer, 1)
    end
    -- File
    writeToFile(msg)
    -- Console
    local Executor = require(script.Parent.executor)
    if Executor.info.capabilities.rconsole then
        Executor.console_print(msg)
    else
        print(msg)
    end
end

function Log.debug(...) log(Levels.DEBUG, ...) end
function Log.info(...) log(Levels.INFO, ...) end
function Log.warn(...) log(Levels.WARN, ...) end
function Log.error(...) log(Levels.ERROR, ...) end
function Log.fatal(...) log(Levels.FATAL, ...) end

function Log.getBuffer()
    return logBuffer
end

function Log.clearBuffer()
    logBuffer = {}
end

return Log