require "import"
import "android.app.*"
import "android.os.*"
import "android.content.*"
import "android.media.*"
import "java.util.*"
import "java.io.File"

local context = service or activity

if _G.URDU_CLOCK_SPEAKING == nil then _G.URDU_CLOCK_SPEAKING = false end
if _G.URDU_CLOCK_LAST_MIN == nil then _G.URDU_CLOCK_LAST_MIN = -1 end

local function findAudio(fileName)
  local luaDir = tostring(context.getLuaDir()).."/"
  
  local paths = {
    luaDir,
    "/sdcard/解说/Plugins/Urdu Clock Final Pro/",
    "/storage/emulated/0/解说/Plugins/Urdu Clock Final Pro/",
    "/sdcard/解说/Plugins/Urdu_Clock/",
    "/storage/emulated/0/解说/Plugins/Urdu_Clock/",
    "/sdcard/解说/Plugins/Urdu/",
    "/storage/emulated/0/解说/Plugins/Urdu/",
    "/sdcard/Plugins/Urdu_Clock/",
    "/storage/emulated/0/Plugins/Urdu_Clock/",
    "/sdcard/Urdu_Clock/",
    "/storage/emulated/0/Urdu_Clock/"
  }

  for i=1,#paths do
    local p=paths[i]
    if File(p..fileName..".mp3").exists() then
      return p..fileName..".mp3"
    elseif File(p..fileName..".ogg").exists() then
      return p..fileName..".ogg"
    end
  end
  return nil
end

local function playAudio(fileName, callback)
  local finalPath = findAudio(fileName)

  if finalPath then
    local mp = MediaPlayer()
    mp.setDataSource(finalPath)
    mp.setAudioStreamType(AudioManager.STREAM_MUSIC)
    mp.prepare()
    mp.start()

    mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{
      onCompletion=function(m)
        m.release()
        if callback then callback() end
      end
    })
    return true
  else
    if fileName ~= "Cuckoo" then
      service.speak(fileName)
    end
    if callback then callback() end
    return false
  end
end

function main()
  if _G.URDU_CLOCK_SPEAKING then return true end
  _G.URDU_CLOCK_SPEAKING = true

  local cal = Calendar.getInstance()
  local min = cal.get(Calendar.MINUTE)
  local hour = cal.get(Calendar.HOUR_OF_DAY)

  local pm = context.getSystemService(Context.POWER_SERVICE)
  local wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "UrduClock:WakeLock")

  if not wakeLock.isHeld() then
    wakeLock.acquire(15000)
  end

  playAudio("Cuckoo", function()
    if min == 0 then
      playAudio("h"..hour, function()
        _G.URDU_CLOCK_SPEAKING = false
        if wakeLock.isHeld() then wakeLock.release() end
      end)
    else
      playAudio("hb"..hour, function()
        playAudio("m"..min, function()
          _G.URDU_CLOCK_SPEAKING = false
          if wakeLock.isHeld() then wakeLock.release() end
        end)
      end)
    end
  end)

  return true
end

local function startAutoTimer()
  if _G.URDU_CLOCK_MAIN_HANDLER then
    pcall(function()
      _G.URDU_CLOCK_MAIN_HANDLER.removeCallbacksAndMessages(nil)
    end)
  end
  
  _G.URDU_CLOCK_MAIN_HANDLER = Handler(Looper.getMainLooper())
  local runnable
  
  runnable = Runnable({
    run=function()
      local cal = Calendar.getInstance()
      local min = cal.get(Calendar.MINUTE)

      if (min == 0 or min == 30) then
        if min ~= _G.URDU_CLOCK_LAST_MIN and not _G.URDU_CLOCK_SPEAKING then
          _G.URDU_CLOCK_LAST_MIN = min 
          main()
        end
      else
        _G.URDU_CLOCK_LAST_MIN = -1
      end

      _G.URDU_CLOCK_MAIN_HANDLER.postDelayed(runnable, 2000) 
    end
  })

  _G.URDU_CLOCK_MAIN_HANDLER.postDelayed(runnable, 1000)
end

pcall(function()
  startAutoTimer()

  plugin.register({
    name="Urdu Clock Final Pro",
    id="urdu_clock_pro_janbaz",
    author="Janbaz Hijbani",
    version="13.0", 
    menus={
      {"Check Time", main}
    }
  })
end)

local currentMin = Calendar.getInstance().get(Calendar.MINUTE)
if currentMin ~= 0 and currentMin ~= 30 then
  main()
end