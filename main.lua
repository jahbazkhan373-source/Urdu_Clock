require "import"
import "android.app.*"
import "android.os.*"
import "android.content.*"
import "android.media.*"
import "java.util.*"
import "java.io.File"

local context = service or activity

-- گلوبل ویری ایبلز کا استعمال تاکہ ری لوڈ ہونے پر بھی ڈیٹا ضائع نہ ہو
if _G.URDU_CLOCK_SPEAKING == nil then _G.URDU_CLOCK_SPEAKING = false end
if _G.URDU_CLOCK_LAST_MIN == nil then _G.URDU_CLOCK_LAST_MIN = -1 end
if _G.URDU_CLOCK_TIMER_RUNNING == nil then _G.URDU_CLOCK_TIMER_RUNNING = false end

-- آواز تلاش کرنے کا زبردست فنکشن (جو اب ہر نام اور فولڈر کو سپورٹ کرے گا)
local function findAudio(fileName)
  local luaDir = tostring(context.getLuaDir()).."/"
  
  -- تمام ممکنہ راستوں کی لسٹ
  local paths = {
    luaDir, -- سب سے پہلے اس فولڈر کو چیک کرے گا جہاں پلگ ان انسٹال ہے (نام کا مسئلہ حل)
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

-- آواز چلانے کا تیز ترین فنکشن
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
  if _G.URDU_CLOCK_SPEAKING then return true end
  _G.URDU_CLOCK_SPEAKING = true

  local cal = Calendar.getInstance()
  local min = cal.get(Calendar.MINUTE)
  local hour = cal.get(Calendar.HOUR_OF_DAY)

  -- پاور مینجمنٹ (سکرین لاک میں 24 گھنٹے ورکنگ یقینی بنانے کے لیے)
  local pm = context.getSystemService(Context.POWER_SERVICE)
  local wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "UrduClock:WakeLock")

  if not wakeLock.isHeld() then
    wakeLock.acquire(15000)
  end

  -- پلے لسٹ ترتیب: ککو -> گھنٹہ -> منٹ
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

-- آٹو ٹائمر (ڈبلنگ اور گونج سے پاک تالا)
local function startAutoTimer()
  -- اگر پورے سسٹم میں ایک بار ٹائمر چل گیا تو دوسرا کبھی نہیں بنے گا
  if _G.URDU_CLOCK_TIMER_RUNNING then return end
  _G.URDU_CLOCK_TIMER_RUNNING = true

  local handler = Handler(Looper.getMainLooper())
  local runnable
  
  runnable = Runnable({
    run=function()
      local cal = Calendar.getInstance()
      local min = cal.get(Calendar.MINUTE)

      -- صرف 00 اور 30 منٹ پر چلے گا
      if (min == 0 or min == 30) then
        if min ~= _G.URDU_CLOCK_LAST_MIN and not _G.URDU_CLOCK_SPEAKING then
          _G.URDU_CLOCK_LAST_MIN = min -- منٹ کو فوراً لاک کریں تاکہ دوبارہ لوپ نہ چلے
          main()
        end
      else
        -- جب منٹ 00 یا 30 نہ ہو تو تالا کھول دیں تاکہ اگلے آدھے گھنٹے کے لیے تیار ہو جائے
        _G.URDU_CLOCK_LAST_MIN = -1
      end

      handler.postDelayed(runnable, 2000) -- ہر 2 سیکنڈ بعد سمارٹ چیکنگ
    end
  })

  handler.postDelayed(runnable, 1000)
end

-- پلگ ان رجسٹریشن اور سیٹ اپ
pcall(function()
  startAutoTimer()

  plugin.register({
    name="Urdu Clock Final Pro",
    id="urdu_clock_pro_janbaz",
    author="Janbaz Hijbani",
    version="12.5", -- ورژن اپڈیٹ
    menus={
      {"Check Time", main}
    }
  })
end)

-- جب آپ خود پلگ ان اپلائی کریں تو فوراً ٹائم بتائے گا
-- لیکن اگر اٹو ٹائمر کا وقت ہو تو یہ مینوئل رن اوور لیپ نہیں کرے گا
local currentMin = Calendar.getInstance().get(Calendar.MINUTE)
if currentMin ~= 0 and currentMin ~= 30 then
  main()
end