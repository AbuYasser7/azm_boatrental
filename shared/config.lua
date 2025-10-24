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
        name = "استئجار قوارب العزم لوس",
        blip = { x = 23.77, y = -2806.98, z = 5.7 },
        ped  = { x = 23.77, y = -2806.98, z = 5.7, heading = 2.38, model = "a_m_y_surfer_01" },
        menu = { x = 23.77, y = -2806.98, z = 5.7, heading = 2.38 },
        spawns = {
            {x = 14.88, y = -2822.49, z = 7.03, h = 5.79},
            {x = 24.88, y = -2826.72, z = 5.54, h = 4.6},
            {x = 37.58, y = -2825.81, z = 5.54, h = 2.87},
        },
        returnZone = { x = -5.82, y = -2768.88, z = 4.96, w = 8.0, l = 8.0, h = 3.0 },
    },
    {
        id = 2,
        name = "استئجار قوارب العزم بوليتو",
        blip = { x = -281.12, y = 6635.53, z = 7.56 },
        ped  = { x = -281.12, y = 6635.53, z = 7.56, heading = 230.26, model = "a_m_y_beach_02" },
        menu = { x = -281.12, y = 6635.53, z = 7.56, heading = 230.26 },
        spawns = {
            {x = -291.59, y = 6635.82, z = 3, h = 16.62},
            {x = -285.34, y = 6637.68, z = 3, h = 75.29},
            {x = -279.55, y = 6643.45, z = 3, h = 9.22},
        },
        returnZone = { x = -806.12, y = -1498.12, z = 0.2, w = 8.0, l = 8.0, h = 3.0 },
    },
}

-- =============== Localization (Locales) ===============
AZM.Locales = {
    ['en'] = {
        ['ui.title']        = 'Boat Rental',
        ['ui.blip_name']    = 'Boat Rental',
        ['ui.open_shop']    = 'Open shop: %s',
        ['ui.owner_panel']  = 'Owner Panel',
        ['ui.return_boat']  = 'Return Rented Boat',
        ['ui.amount']       = 'Amount',
        ['ui.new_price']    = 'New Price',
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
        -- عناوين وواجهات
        ['ui.title']        = 'تأجير القوارب',
        ['ui.blip_name']    = 'مكان تأجير القوارب',
        ['ui.open_shop']    = 'فتح المتجر: %s',
        ['ui.owner_panel']  = 'لوحة المالك',
        ['ui.return_boat']  = 'إرجاع القارب',
        ['ui.amount']       = 'المبلغ',
        ['ui.new_price']    = 'السعر الجديد',
        ['ui.top_left_prompt'] = 'اضغط E للتفاعل', -- يظهر بجانب صندوق المفتاح

        -- تلميحات (زر E)
        ['hint.press_e_rent']   = 'اضغط ~INPUT_PICKUP~ للاستئجار',
        ['hint.press_e_owner']  = 'اضغط ~INPUT_PICKUP~ لفتح لوحة المالك',
        ['hint.press_e_return'] = 'اضغط ~INPUT_PICKUP~ لإرجاع القارب هنا',

        -- إشعارات قصيرة للمستخدم
        ['notif.enjoy']     = 'استمتع برحلتك على %s!',
        ['notif.destroyed'] = 'تم تدمير القارب. يمكنك الاستئجار مرة أخرى.',
        ['notif.returned']  = 'تم إرجاع القارب بنجاح!',

        -- أخطاء وإرشادات واضحة بالعربية
        ['error.cannot_rent']        = 'لا يمكنك الاستئجار حالياً.',
        ['error.no_catalog']         = 'لا توجد قوارب متاحة الآن.',
        ['error.no_catalog_shop']    = 'لا توجد قوارب مُعرفة لهذا المتجر.',
        ['error.no_rental_this_shop']= 'ليس لديك إيجار نشط من هذا المتجر.',
        ['error.boat_not_found']     = 'لم يتم العثور على القارب.',
        ['error.owner_panel']        = 'لوحة المالك غير متاحة حالياً.',
        ['error.model_load_failed']  = 'فشل تحميل موديل: %s',
        ['error.spawn_failed']       = 'فشل إنشاء القارب في الموقع.',
        ['error.no_active_rental']   = 'ليس لديك أي إيجار حالياً.',
        ['error.no_spawn']           = 'لا توجد نقاط إفراغ/استدعاء متاحة حالياً.',
        ['error.boat_unavailable']   = 'القارب غير متوفر حالياً.',
        ['error.need_money']         = 'تحتاج إلى $%d (السعر + الوديعة).',
        ['error.price_out_of_range'] = 'السعر خارج النطاق المسموح (%d - %d).',
        ['error.active_rental']      = 'لديك إيجار نشط بالفعل.',
        ['error.must_wait']          = 'عليك الانتظار %02d:%02d قبل استئجار آخر.',
        ['error.shop_not_found']     = 'المتجر غير موجود.',
        ['error.not_owner']          = 'أنت لست مالك هذا المتجر.',
        ['success.transfered']       = 'تم نقل ملكية المتجر بنجاح.',
        ['success.claim_platform']   = 'تم سحب $%d من خزنة المنصة.',
        ['admin.no_permission']      = 'ليس لديك صلاحية تنفيذ هذا الإجراء.',

        -- القوائم وواجهات المالك
        ['menu.boats_title']         = '%s — القوارب المتاحة',
        ['menu.owner_title']         = 'لوحة المالك — %s',
        ['menu.withdraw_custom']     = 'سحب (مخصص)',
        ['menu.deposit_custom']      = 'إيداع (مخصص)',
        ['menu.set_prices']          = 'تعديل الأسعار',
        ['menu.refresh']             = 'تحديث',
        ['menu.set_price_for']       = 'تعيين سعر %s',

        -- تفاصيل الخزنة والمالك
        ['owner.shop']           = 'المتجر: %s',
        ['owner.balance']        = 'الرصيد: $%d',
        ['owner.platform_fee']   = 'نسبة المنصة: %d%%',
        ['owner.deposit_default']= 'الوديعة الافتراضية: $%d',
        ['owner.withdraw_1000']  = 'سحب $1,000',
        ['owner.withdraw_5000']  = 'سحب $5,000'
    }
}
