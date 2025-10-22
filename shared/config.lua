-- Built for Al Azm County by abuyasser (discord.gg/azm)

AZM = {}

-- =============== General Settings ===============
AZM.Debug = false                     -- تفعيل وضع التصحيح (debug)
AZM.CooldownMinutes = 60              -- يمنع الاستئجار مرة أخرى قبل (دقائق)

-- اللغة الافتراضية: 'en' أو 'ar'
AZM.Locale = 'ar'

AZM.Groups = {
    SuperAdmin = { 'superadmin', 'admin' } -- صلاحيات الإدارة العليا
}

-- =============== Interaction & Notifications ===============
-- نظام التنبيهات: 'moh' أو 'pnotify' أو 'ox' (الافتراضي ox_lib)
AZM.Notify = 'moh'

-- طريقة التفاعل: 'key' لزر E، أو 'target' لاستخدام ox_target
AZM.Interact    = 'key'
AZM.InteractKey = 38                  -- 38 = INPUT_PICKUP (E)

-- =============== Webhooks & Logging ===============
AZM.Webhooks = {
    -- ضع رابط الويب هوك الخاص بك
    main = "https://discord.com/api/webhooks/1430573542381981837/ayPtUI5MyPrMu7TWIq5Dt9uSxP6CIbe3ahBI8U92AL2lpK_G0YEnoqpBFmPqANn7atqO"
}

AZM.Logs = {
    enable   = true,
    username = "🚤 Al Azm Boat Rental | Logs",
    avatar   = "https://raw.githubusercontent.com/AbuYasser7/azmrp/refs/heads/main/128.png"
}

-- =============== Boat Catalog ===============
AZM.Boats = {
    { model = 'dinghy2',  label = 'قارب صغير',     price = 3000 },
    { model = 'seashark', label = 'جيت سكي',        price = 4000 },
    { model = 'speeder',  label = 'سبيدر',          price = 6000 },
    { model = 'toro',     label = 'تورو',           price = 8000 },
    { model = 'jetmax',   label = 'جيتماكس',        price = 10000 },
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

-- =============== Localization (Locales) ===============
AZM.Locales = {
    ['en'] = {
        ['ui.title']        = 'Boat Rental',
        ['ui.blip_name']    = 'Boat Rental',
        ['ui.owner_panel']  = 'Owner Panel',
        ['ui.return_boat']  = 'Return Rented Boat',
        ['ui.amount']       = 'Amount',
        ['ui.new_price']    = 'New Price',
        -- تلميحات زر E
        ['hint.press_e_rent']   = 'Press ~INPUT_PICKUP~ to rent a boat',
        ['hint.press_e_owner']  = 'Press ~INPUT_PICKUP~ to open Owner Panel',
        ['hint.press_e_return'] = 'Press ~INPUT_PICKUP~ to return your boat',

        ['notif.enjoy']     = 'Enjoy your %s!',
        ['notif.destroyed'] = 'Boat destroyed. You may rent again.',
        ['notif.returned']  = 'Boat returned successfully!',

        ['error.cannot_rent']        = 'You cannot rent right now.',
        ['error.no_catalog']         = 'No boats available right now.',
        ['error.no_catalog_shop']    = 'No boats configured for this shop.',
        ['error.no_rental_this_shop']= 'You have no active rental for this shop.',
        ['error.boat_not_found']     = 'Boat not found.',
        ['error.owner_panel']        = 'Owner panel not available.',
        ['error.model_load_failed']  = 'Failed to load model: %s',
        ['error.spawn_failed']       = 'Failed to spawn the boat.',
        ['error.no_active_rental']   = 'You have no active rental.',

        ['menu.boats_title']         = '%s — Boats',
        ['menu.owner_title']         = 'Owner Panel — %s',
        ['menu.withdraw_custom']     = 'Withdraw (custom)',
        ['menu.deposit_custom']      = 'Deposit (custom)',
        ['menu.set_prices']          = 'Set Prices',
        ['menu.refresh']             = 'Refresh',
        ['menu.set_price_for']       = 'Set price for %s',

        ['owner.shop']           = 'Shop: %s',
        ['owner.balance']        = 'Balance: $%d',
        ['owner.platform_fee']   = 'Platform Fee: %d%%',
        ['owner.deposit_default']= 'Deposit Default: $%d',
        ['owner.withdraw_1000']  = 'Withdraw $1,000',
        ['owner.withdraw_5000']  = 'Withdraw $5,000'
    },

    ['ar'] = {
        ['ui.title']        = 'تأجير القوارب',
        ['ui.blip_name']    = 'نقطة تأجير القوارب',
        ['ui.open_shop']    = 'فتح متجر: %s',
        ['ui.owner_panel']  = 'لوحة المالك',
        ['ui.return_boat']  = 'إرجاع القارب',
        ['ui.amount']       = 'المبلغ',
        ['ui.new_price']    = 'السعر الجديد',

        -- تلميحات (مفاتيح E) — بالعربية فقط (بدون أي حرف إنجليزي)
        ['hint.press_e_rent']   = 'اضغط ~INPUT_PICKUP~ للاستئجار',
        ['hint.press_e_owner']  = 'اضغط ~INPUT_PICKUP~ للوصول إلى لوحة المالك',
        ['hint.press_e_return'] = 'اضغط ~INPUT_PICKUP~ لإرجاع القارب هنا',

        -- إشعارات
        ['notif.enjoy']     = 'استمتع برحلتك على %s!',
        ['notif.destroyed'] = 'تم تدمير القارب، يمكنك الاستئجار مرة أخرى.',
        ['notif.returned']  = 'تم إرجاع القارب بنجاح!',

        -- أخطاء وإرشادات
        ['error.cannot_rent']        = 'لا يمكنك الاستئجار الآن.',
        ['error.no_catalog']         = 'لا توجد قوارب متاحة حالياً.',
        ['error.no_catalog_shop']    = 'لا توجد قوارب مخصصة لهذا المتجر.',
        ['error.no_rental_this_shop']= 'ليس لديك استئجار نشط لهذا المتجر.',
        ['error.boat_not_found']     = 'لم يتم العثور على القارب.',
        ['error.owner_panel']        = 'لوحة المالك غير متاحة.',
        ['error.model_load_failed']  = 'فشل تحميل الموديل: %s',
        ['error.spawn_failed']       = 'حدث خطأ أثناء إنشاء القارب.',
        ['error.no_active_rental']   = 'ليس لديك أي قارب مستأجر حالياً.',

        -- قوائم وواجهات
        ['menu.boats_title']         = '%s — القوارب المتاحة',
        ['menu.owner_title']         = 'لوحة المالك — %s',
        ['menu.withdraw_custom']     = 'سحب (مخصص)',
        ['menu.deposit_custom']      = 'إيداع (مخصص)',
        ['menu.set_prices']          = 'تعديل الأسعار',
        ['menu.refresh']             = 'تحديث',
        ['menu.set_price_for']       = 'تحديد سعر %s',

        -- تفاصيل المالك
        ['owner.shop']           = 'المتجر: %s',
        ['owner.balance']        = 'الرصيد: $%d',
        ['owner.platform_fee']   = 'نسبة المنصة: %d%%',
        ['owner.deposit_default']= 'الوديعة الافتراضية: $%d',
        ['owner.withdraw_1000']  = 'سحب $1,000',
        ['owner.withdraw_5000']  = 'سحب $5,000'
    }
}
