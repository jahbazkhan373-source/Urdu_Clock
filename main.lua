require "import"
import "android.app.*"
import "android.os.*"
import "android.content.*"
import "android.media.*"
import "java.util.*"
import "java.io.File"

local context = service or activity
local isSpeaking = false
local lastAutoMinute = -1

-- ٹائمر کو ڈبل ہونے سے روکنے کیلئے
if _G.URDU_CLOCK_TIMER_RUNNING == nil then
_G.URDU_CLOCK_TIMER_RUNNING = false
end

-- آواز تلاش کرنے کیلئے متعدد راستے
local function findAudio(fileName)
  local luaDir = tostring(context.getLuaDir()).."/"

  local paths = {
    "/sdcard/解说/Plugins/Urdu_Clock/",
    "/storage/emulated/0/解说/Plugins/Urdu_Clock/",
    "/sdcard/解说/Plugins/",
    "/storage/emulated/0/解说/Plugins/",
    "/sdcard/Plugins/Urdu_Clock/",
    "/storage/emulated/0/Plugins/Urdu_Clock/",
    "/sdcard/Urdu_Clock/",
    "/storage/emulated/0/Urdu_Clock/",
    luaDir
  }

  for i=1,#paths do
    local p=paths[i]
    if File(p..fileName..".mp3").exists() then
      return p..fileName..".mp3"
    end
    if File(p..fileName..".ogg").exists() then
      return p..fileName..".ogg"
    end
  end
  return nil
end

-- آواز چلانے کا فنکشن
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

-- مین ٹائم فنکشن
function main()

  if isSpeaking then return end
  isSpeaking = true

  local cal = Calendar.getInstance()
  local min = cal.get(Calendar.MINUTE)
  local hour = cal.get(Calendar.HOUR_OF_DAY)

  local pm = context.getSystemService(Context.POWER_SERVICE)
  local wakeLock = pm.newWakeLock(
    PowerManager.PARTIAL_WAKE_LOCK,
    "UrduClockLock"
  )

  if not wakeLock.isHeld() then
    wakeLock.acquire(15000)
  end

  playAudio("Cuckoo", function()

    if min == 0 then
      playAudio("h"..hour,function()
        isSpeaking=false
        if wakeLock.isHeld() then wakeLock.release() end
      end)

    else
      playAudio("hb"..hour,function()

        playAudio("m"..min,function()
          isSpeaking=false
          if wakeLock.isHeld() then wakeLock.release() end
        end)

      end)
    end

  end)

  return true
end


-- آٹو ٹائمر
local function startAutoTimer()

  if _G.URDU_CLOCK_TIMER_RUNNING then
    return
  end

  _G.URDU_CLOCK_TIMER_RUNNING = true

  local handler = Handler(Looper.getMainLooper())
  local runnable

  runnable = Runnable({
    run=function()

      local cal = Calendar.getInstance()
      local min = cal.get(Calendar.MINUTE)

      if (min == 0 or min == 30) then
        if min ~= lastAutoMinute then
          lastAutoMinute = min
          main()
        end
      else
        lastAutoMinute = -1
      end

      handler.postDelayed(runnable,2000)
    end
  })

  handler.postDelayed(runnable,1000)
end


pcall(function()

  startAutoTimer()

  plugin.register({
    name="Urdu Clock Final Pro",
    id="urdu_clock_pro_janbaz",
    author="Janbaz Hijbani",
    version="12.0",
    menus={
      {"Check Time",main}
    }
  })

end)

main()