using System;
using System.Collections.Generic;
using System.IO;
using System.Web.Script.Serialization;

namespace AZZikr
{
    public class Zikr
    {
        public string t { get; set; } = "";
        public bool on { get; set; }
        public Zikr() { }
        public Zikr(string text, bool enabled) { t = text; on = enabled; }
    }

    /// Mirrors the `S` object in web/settings.html (and Store.swift on the Mac) — keep the names in sync.
    public class Settings
    {
        public bool enabled { get; set; } = true;
        public string mode { get; set; } = "click";   // click | sec | nth
        public int sec { get; set; } = 5;
        public int nth { get; set; } = 3;
        public int dur { get; set; } = 1600;           // ms
        public int size { get; set; } = 13;            // px
        public string style { get; set; } = "text";   // text | grad | calm | glass | tag | callig
        public string order { get; set; } = "seq";    // seq | rand
        public string pos { get; set; } = "cursor";   // cursor | fixed
        public string corner { get; set; } = "tr";    // tl tc tr bl bc br
        public List<Zikr> azkar { get; set; } = Defaults();

        public static List<Zikr> Defaults() => new List<Zikr> {
            new Zikr("أستغفر الله", true), new Zikr("سبحان الله", true),
            new Zikr("الحمد لله", true), new Zikr("لا إله إلا الله", true),
            new Zikr("الله أكبر", false), new Zikr("اللهم صلِّ على محمد", false),
            new Zikr("سبحان الله وبحمده", false), new Zikr("لا حول ولا قوة إلا بالله", false),
        };
    }

    class DayCount
    {
        public int count { get; set; }
        public string day { get; set; } = "";
    }

    static class Store
    {
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
        static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AZ Zikr");
        static string SettingsPath => Path.Combine(Dir, "settings.json");
        static string CountPath => Path.Combine(Dir, "count.json");

        public static Settings Settings { get; private set; } = new Settings();
        static DayCount counter = new DayCount();
        public static bool IsFirstRun { get; private set; }

        public static void Load()
        {
            IsFirstRun = !File.Exists(SettingsPath);
            try { if (!IsFirstRun) Settings = Json.Deserialize<Settings>(File.ReadAllText(SettingsPath)) ?? new Settings(); }
            catch { Settings = new Settings(); }
            if (Settings.azkar == null || Settings.azkar.Count == 0) Settings.azkar = Settings.Defaults();
            try { if (File.Exists(CountPath)) counter = Json.Deserialize<DayCount>(File.ReadAllText(CountPath)) ?? new DayCount(); }
            catch { counter = new DayCount(); }
            if (IsFirstRun) Save(Settings);
        }

        public static void Save(Settings s)
        {
            if (s.azkar == null || s.azkar.Count == 0) s.azkar = Settings.Defaults();
            Settings = s;
            try { Directory.CreateDirectory(Dir); File.WriteAllText(SettingsPath, Json.Serialize(s)); } catch { }
        }

        public static string SettingsJson => Json.Serialize(Settings);
        public static Settings FromObject(object o) => Json.ConvertToType<Settings>(o);
        public static Dictionary<string, object> Parse(string json) => Json.Deserialize<Dictionary<string, object>>(json);

        static string Today => DateTime.Now.ToString("yyyy-MM-dd");
        static void Roll() { if (counter.day != Today) { counter.day = Today; counter.count = 0; SaveCount(); } }
        public static int Count { get { Roll(); return counter.count; } }
        public static void Increment() { Roll(); counter.count++; SaveCount(); }
        public static void ResetCount() { counter.count = 0; SaveCount(); }
        static void SaveCount()
        {
            try { Directory.CreateDirectory(Dir); File.WriteAllText(CountPath, Json.Serialize(counter)); } catch { }
        }
    }
}
