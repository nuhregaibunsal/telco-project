/*
 * 1.1 - 'Kobiye Destek' tarifesine abone olan müşterileri listeler.
 * CUSTOMERS ile TARIFFS tablolarını TARIFF_ID üzerinden INNER JOIN ile birleştiriyorum
 * çünkü tarifenin ID'si değil isim bilgisi verilmiş; filtreyi TARIFFS.NAME üzerinden uyguluyorum.
 * Sonuçları CUSTOMER_ID'ye göre sıralayarak okunabilirlik sağlıyorum ve aynı sonucun
 * her çalıştırmada aynı sırada dönmesini garanti ediyorum.
 */
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME = 'Kobiye Destek'
ORDER  BY c.CUSTOMER_ID;


/*
 * 1.2 - 'Kobiye Destek' tarifesine abone olanlar içinde en yeni müşteriyi bulur.
 * Tarife filtresi uyguladıktan sonra SIGNUP_DATE'e göre azalan sıralama yapıyorum.
 * Oracle 12c+ 'FETCH FIRST 1 ROW WITH TIES' ile sadece en büyük tarihi alıyorum;
 * WITH TIES sayesinde aynı günde abone olmuş birden fazla müşteri varsa hepsi birden döner.
 */
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
FROM   CUSTOMERS c
JOIN   TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
WHERE  t.NAME = 'Kobiye Destek'
ORDER  BY c.SIGNUP_DATE DESC
FETCH  FIRST 1 ROW WITH TIES;


/*
 * 2.1 - Tarifelerin müşteriler arasındaki dağılımını verir.
 * TARIFFS'i baz alıp LEFT JOIN yapıyorum ki hiç müşterisi olmayan bir tarife varsa
 * sonuca 0 müşteri ile dahil olsun; böylece dağılım tablosu eksiksiz olur.
 * Her tarifenin toplam içindeki yüzdesini hesaplamak için SUM(COUNT(*)) OVER ()
 * pencere fonksiyonunu kullanıyorum; bu sayede tek sorguda hem sayıyı hem oranı alıyorum.
 */
SELECT t.TARIFF_ID,
       t.NAME AS TARIFF_NAME,
       COUNT(c.CUSTOMER_ID) AS CUSTOMER_COUNT,
       ROUND(COUNT(c.CUSTOMER_ID) * 100 /
             SUM(COUNT(c.CUSTOMER_ID)) OVER (), 2) AS PERCENTAGE
FROM   TARIFFS   t
LEFT   JOIN CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP  BY t.TARIFF_ID, t.NAME
ORDER  BY CUSTOMER_COUNT DESC;


/*
 * 3.1 - En erken kayıt olan müşterileri bulur.
 * README ipucunda belirtildiği gibi en erken müşteri mutlaka en küçük ID'ye sahip değildir;
 * bu yüzden ID'ye değil SIGNUP_DATE'e göre artan sıralıyorum.
 * FETCH FIRST 1 ROW WITH TIES kullanarak en küçük tarihi alıyorum ve aynı tarihte
 * kayıt olmuş birden fazla müşteri varsa hepsini sonuca dahil ediyorum.
 */
SELECT CUSTOMER_ID, NAME, CITY, SIGNUP_DATE, TARIFF_ID
FROM   CUSTOMERS
ORDER  BY SIGNUP_DATE ASC
FETCH  FIRST 1 ROW WITH TIES;


/*
 * 3.2 - En erken kayıt olan müşterilerin şehir bazında dağılımını verir.
 * 3.1 ile aynı filtreyi (MIN SIGNUP_DATE) kullanarak aynı müşteri kümesi üzerinde çalışıyorum.
 * GROUP BY CITY ile her şehirdeki müşteri sayısını hesaplıyor ve toplam sayıyı da sunuyorum.
 * Sıralamayı önce sayıya göre azalan, sonra şehir adına göre yaparak raporu okunabilir yapıyorum.
 */
SELECT CITY, COUNT(*) AS CUSTOMER_COUNT
FROM   CUSTOMERS
WHERE  SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
GROUP  BY CITY
ORDER  BY CUSTOMER_COUNT DESC, CITY;


/*
 * 4.1 - Aylık kaydı eksik olan müşterilerin ID'lerini bulur.
 * CUSTOMERS tablosunu MONTHLY_STATS ile LEFT JOIN yapıyorum ki her müşteri sonuca dahil olsun.
 * MONTHLY_STATS tarafından eşleşen satır gelmediyse m.CUSTOMER_ID değeri NULL olur ve
 * bu NULL kontrolü ile aylık kaydı olmayan müşterileri (anti-join) tespit ediyorum.
 * NOT EXISTS da aynı sonucu verir; LEFT JOIN / IS NULL tercihim ek kolonları da dönebilmek için.
 */
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.TARIFF_ID
FROM   CUSTOMERS c
LEFT   JOIN MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  m.CUSTOMER_ID IS NULL
ORDER  BY c.CUSTOMER_ID;


/*
 * 4.2 - Aylık kaydı eksik müşterilerin şehirlere göre dağılımını verir.
 * 4.1'deki anti-join mantığını (LEFT JOIN + IS NULL) aynen kullanıyorum ki eksik küme aynen gelsin.
 * Sonrasında GROUP BY CITY ile şehir başı eksik müşteri sayısını hesaplıyorum.
 * Çıktı, hangi şehirlerde veri kalitesi sorununun daha yoğun olduğunu gösterir.
 */
SELECT c.CITY, COUNT(*) AS MISSING_CUSTOMERS
FROM   CUSTOMERS c
LEFT   JOIN MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  m.CUSTOMER_ID IS NULL
GROUP  BY c.CITY
ORDER  BY MISSING_CUSTOMERS DESC, c.CITY;


/*
 * 5.1 - Data limitinin en az %75'ini kullanmış müşterileri bulur.
 * Her müşterinin kullanımı (MONTHLY_STATS.DATA_USAGE) kendi tarifesinin limitiyle karşılaştırılmalı,
 * bu yüzden CUSTOMERS, TARIFFS ve MONTHLY_STATS tablolarını birlikte JOIN ediyorum.
 * DATA_LIMIT > 0 kontrolünü ekliyorum çünkü data limiti 0 olan tarifelerde (örn. Kurumsal SMS)
 * yüzde hesabı anlamsız olur ve ayrıca sıfıra bölme hatası riskini ortadan kaldırır.
 */
SELECT c.CUSTOMER_ID,
       c.NAME,
       t.NAME                                  AS TARIFF_NAME,
       m.DATA_USAGE,
       t.DATA_LIMIT,
       ROUND(m.DATA_USAGE * 100 / t.DATA_LIMIT, 2) AS USAGE_PERCENT
FROM   CUSTOMERS     c
JOIN   TARIFFS       t ON t.TARIFF_ID   = c.TARIFF_ID
JOIN   MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  t.DATA_LIMIT > 0
AND    m.DATA_USAGE >= 0.75 * t.DATA_LIMIT
ORDER  BY USAGE_PERCENT DESC;


/*
 * 5.2 - Tüm paket limitlerini (data, dakika, SMS) tamamen tüketmiş müşterileri bulur.
 * Üç kaynağın da limitin üzerine çıkmış olması gerekir; bu yüzden üç AND koşulu birlikte uygulanıyor.
 * Her limit için '> 0' kontrolü var çünkü limit=0 olan bir kaynakta 'tüketme' kavramı anlamsız olur;
 * bir tarifede hangi kaynağın aktif olduğunu bu şekilde geçerli şekilde elemiş oluyorum.
 * Sonuca karşılaştırma için hem kullanım hem limit kolonlarını birlikte döndürüyorum.
 */
SELECT c.CUSTOMER_ID,
       c.NAME,
       t.NAME AS TARIFF_NAME,
       m.DATA_USAGE,    t.DATA_LIMIT,
       m.MINUTE_USAGE,  t.MINUTE_LIMIT,
       m.SMS_USAGE,     t.SMS_LIMIT
FROM   CUSTOMERS     c
JOIN   TARIFFS       t ON t.TARIFF_ID   = c.TARIFF_ID
JOIN   MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  t.DATA_LIMIT    > 0 AND m.DATA_USAGE   >= t.DATA_LIMIT
AND    t.MINUTE_LIMIT  > 0 AND m.MINUTE_USAGE >= t.MINUTE_LIMIT
AND    t.SMS_LIMIT     > 0 AND m.SMS_USAGE    >= t.SMS_LIMIT
ORDER  BY c.CUSTOMER_ID;


/*
 * 6.1 - Ödenmemiş ücreti olan müşterileri bulur.
 * Ödeme bilgisi MONTHLY_STATS tablosunda PAYMENT_STATUS alanında tutulduğu için bu tablodan filtreliyorum.
 * Müşterinin adı, şehri ve tarifesinin ücret bilgisini de eklemek için CUSTOMERS ve TARIFFS ile JOIN yapıyorum,
 * böylece tahsilat ekibi kimden ne kadar alacağı ve nerede yaşadığı bilgisini tek rapordan görebilir.
 */
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, t.NAME AS TARIFF_NAME, t.MONTHLY_FEE
FROM   CUSTOMERS     c
JOIN   TARIFFS       t ON t.TARIFF_ID   = c.TARIFF_ID
JOIN   MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  m.PAYMENT_STATUS = 'UNPAID'
ORDER  BY c.CUSTOMER_ID;


/*
 * 6.2 - Tüm ödeme durumlarının tarifelere göre dağılımını verir.
 * Tarife ve ödeme durumu ikilisine göre GROUP BY yaparak çapraz tablo (matrix) şeklinde sayım alıyorum.
 * Her tarifenin kendi içindeki oranı görebilmek için SUM(COUNT(*)) OVER (PARTITION BY t.TARIFF_ID)
 * pencere fonksiyonunu kullanıyorum; bu sayede bir tarifenin %kaçı PAID, %kaçı UNPAID açıkça görülür.
 * Tarifeler arasında kıyas yapabilmek için çıktıyı önce tarife adına sonra ödeme durumuna göre sıralıyorum.
 */
SELECT t.NAME                AS TARIFF_NAME,
       m.PAYMENT_STATUS,
       COUNT(*)              AS CUSTOMER_COUNT,
       ROUND(COUNT(*) * 100 /
             SUM(COUNT(*)) OVER (PARTITION BY t.TARIFF_ID), 2) AS PERCENT_WITHIN_TARIFF
FROM   TARIFFS       t
JOIN   CUSTOMERS     c ON c.TARIFF_ID   = t.TARIFF_ID
JOIN   MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
GROUP  BY t.TARIFF_ID, t.NAME, m.PAYMENT_STATUS
ORDER  BY t.NAME, m.PAYMENT_STATUS;
