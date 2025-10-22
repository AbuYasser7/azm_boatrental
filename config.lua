-- azm_boatrental / config.lua
-- Built for Al Azm County by abuyasser (discord.gg/azm)

AZM = {}

-- =============== General Settings ===============
AZM.Debug = false                     -- عرض مناطق الـ Target
AZM.CooldownMinutes = 60              -- يمنع اللاعب من استئجار مرة أخرى قبل مرور ساعة بعد ترك القارب
AZM.Locale = 'en'                     -- اللغة الافتراضية (يمكن لاحقًا ربطها بالـ ox_lib locales)
AZM.Groups = {
    SuperAdmin = { 'superadmin', 'admin' } -- صلاحيات الإدارة العليا
}

-- =============== Boat Catalog ===============
AZM.Boats = {
    { model = 'dinghy2', label = 'Dinghy', price = 300 },
    { model = 'seashark', label = 'Seashark', price = 250 },
    { model = 'speeder', label = 'Speeder', price = 600 },
    { model = 'toro', label = 'Toro', price = 800 },
    { model = 'jetmax', label = 'Jetmax', price = 900 },
}

-- =============== Boat Shops ===============
AZM.Shops = {
    {
        id = 1,
        name = "Al Azm Marina 1",
        blip = { x = -1600.08, y = -1176.98, z = 1.51 },
        ped  = { x = -1600.08, y = -1176.98, z = 0.51, heading = 300.47, model = "a_m_y_surfer_01" },
        menu = { x = -1600.08, y = -1176.98, z = 1.51, heading = 0.88 },
        spawns = {
            { x = -1630.47, y = -1191.95, z = 0.12, h = 104.88 },
            { x = -1635.11, y = -1194.72, z = 0.10, h = 105.14 },
            { x = -1639.12, y = -1198.00, z = 0.10, h = 106.12 },
        },
        returnZone = { x = -1625.0, y = -1187.5, z = 0.2, w = 8.0, l = 8.0, h = 3.0 },
    },
    {
        id = 2,
        name = "Al Azm Marina 2",
        blip = { x = -801.21, y = -1492.77, z = 1.60 },
        ped  = { x = -801.21, y = -1492.77, z = 0.60, heading = 180.00, model = "a_m_y_beach_02" },
        menu = { x = -801.21, y = -1492.77, z = 1.60, heading = 180.00 },
        spawns = {
            { x = -808.45, y = -1500.33, z = 0.15, h = 170.88 },
            { x = -813.42, y = -1504.21, z = 0.15, h = 171.12 },
        },
        returnZone = { x = -806.12, y = -1498.12, z = 0.2, w = 8.0, l = 8.0, h = 3.0 },
    },
    {
        id = 3,
        name = "Al Azm Marina 3",
        blip = { x = -295.15, y = 6637.31, z = 7.43 },
        ped  = { x = -295.15, y = 6637.31, z = 6.43, heading = 130.00, model = "a_m_y_beach_03" },
        menu = { x = -295.15, y = 6637.31, z = 7.43, heading = 130.00 },
        spawns = {
            { x = -300.22, y = 6634.12, z = 0.12, h = 140.00 },
            { x = -304.18, y = 6631.41, z = 0.12, h = 142.00 },
        },
        returnZone = { x = -297.8, y = 6635.1, z = 0.3, w = 7.5, l = 7.5, h = 3.0 },
    },
}

-- =============== Developer Notes ===============
-- تقدر تضيف مجمعات جديدة للمارينات عن طريق نسخ نفس النموذج وتغيير الإحداثيات
-- كل متجر له بيانات مستقلة في قاعدة البيانات: المالك، الرصيد، الأسعار، مدة الملكية
-- كل متجر ممكن يشتغل في مكان مختلف بدون تعارض
-- بعد التحديث الأول سيتم توليد البيانات في MySQL تلقائياً
