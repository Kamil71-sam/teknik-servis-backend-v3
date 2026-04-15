--
-- PostgreSQL database dump
--

\restrict 4arXeXo1YEZqVyI60Jo12gVn1jl7UvbPaWTiDahkfoO1FmuMXZjknP0WgEaLhUP

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: generate_daily_servis_no(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_daily_servis_no() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    today_prefix TEXT;
    daily_count INTEGER;
BEGIN
    -- Bugünün tarihini al (Format: 260310)
    today_prefix := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Bugün bu prefix ile başlayan kaç kayıt var?
    SELECT COUNT(*) + 1 INTO daily_count 
    FROM services 
    WHERE servis_no LIKE today_prefix || '%';
    
    -- Yeni numarayı birleştir (Örn: 260310 + 01)
    NEW.servis_no := today_prefix || LPAD(daily_count::TEXT, 2, '0');
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_daily_servis_no() OWNER TO postgres;

--
-- Name: log_price_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_price_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Eğer alış veya satış fiyatında bir oynama olursa arşive yaz
    IF (OLD.alis_fiyati IS DISTINCT FROM NEW.alis_fiyati OR OLD.satis_fiyati IS DISTINCT FROM NEW.satis_fiyati) THEN
        INSERT INTO price_history (inventory_id, eski_alis, yeni_alis, eski_satis, yeni_satis)
        VALUES (OLD.id, OLD.alis_fiyati, NEW.alis_fiyati, OLD.satis_fiyati, NEW.satis_fiyati);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_price_changes() OWNER TO postgres;

--
-- Name: trg_daily_appointment_no_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_daily_appointment_no_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix TEXT;
    next_seq INTEGER;
BEGIN
    -- 1. KURAL: Eğer Node.js (Karakutu) zaten numara ürettiyse (ve ESKI değilse), KARIŞMA!
    IF NEW.servis_no IS NOT NULL AND NEW.servis_no != '' AND NEW.servis_no NOT LIKE 'ESKI%' THEN
        RETURN NEW;
    END IF;

    -- 2. KURAL: Numara boş gelirse, HEM Randevu HEM Servis tablosuna bakıp en büyüğü bul!
    prefix := to_char(CURRENT_DATE, 'YYMMDD');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(servis_no FROM 7) AS INTEGER)), 0) + 1
    INTO next_seq
    FROM (
        SELECT servis_no FROM services WHERE servis_no LIKE prefix || '%'
        UNION ALL
        SELECT servis_no FROM appointments WHERE servis_no LIKE prefix || '%'
    ) combined;

    NEW.servis_no := prefix || lpad(next_seq::text, 2, '0');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_daily_appointment_no_func() OWNER TO postgres;

--
-- Name: trg_daily_servis_no_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_daily_servis_no_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix TEXT;
    next_seq INTEGER;
BEGIN
    -- 1. KURAL: Eğer Node.js zaten bir numara ürettiyse, HİÇ KARIŞMA, direkt onu kaydet!
    IF NEW.servis_no IS NOT NULL AND NEW.servis_no != '' THEN
        RETURN NEW;
    END IF;

    -- 2. KURAL: Eğer numara boş gelirse (örn: veritabanı sıfırlandığında elle girilirse), İKİ TABLOYA DA BAK!
    prefix := to_char(CURRENT_DATE, 'YYMMDD');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(servis_no FROM 7) AS INTEGER)), 0) + 1
    INTO next_seq
    FROM (
        SELECT servis_no FROM services WHERE servis_no LIKE prefix || '%'
        UNION ALL
        SELECT servis_no FROM appointments WHERE servis_no LIKE prefix || '%'
    ) combined;

    NEW.servis_no := prefix || lpad(next_seq::text, 2, '0');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_daily_servis_no_func() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    id integer NOT NULL,
    customer_id integer,
    device_id integer,
    appointment_date date NOT NULL,
    appointment_time time without time zone NOT NULL,
    assigned_usta text,
    issue_text text,
    status text DEFAULT 'Beklemede'::text,
    is_confirmed boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    servis_no character varying(20),
    firm_id integer,
    price numeric(10,2) DEFAULT 0,
    usta_notu text,
    usta_maliyet numeric(10,2) DEFAULT 0,
    tahsil_edilen_tutar numeric(10,2) DEFAULT 0,
    mali_onay_durumu boolean DEFAULT false,
    yonetici_notu text
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.appointments_id_seq OWNER TO postgres;

--
-- Name: appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.appointments_id_seq OWNED BY public.appointments.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    name text NOT NULL,
    phone text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fax text,
    email text,
    address text,
    musteri_turu text DEFAULT 'bireysel'::text
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devices (
    id integer NOT NULL,
    customer_id integer,
    brand text,
    model text,
    serial_no text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    cihaz_turu character varying(50),
    garanti_durumu character varying(50),
    muster_notu text,
    firm_id integer
);


ALTER TABLE public.devices OWNER TO postgres;

--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.devices_id_seq OWNER TO postgres;

--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.id;


--
-- Name: envanter; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.envanter (
    id integer NOT NULL,
    barkod character varying(100) NOT NULL,
    malzeme_adi character varying(255) NOT NULL,
    uyumlu_cihaz character varying(255),
    marka character varying(100),
    miktar integer DEFAULT 0 NOT NULL,
    alis_fiyati numeric(10,2) DEFAULT 0.00,
    son_guncelleme timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    satis_fiyati numeric(10,2) DEFAULT 0,
    kar_orani_ozel numeric(10,2),
    kdv_orani_ozel numeric(10,2)
);


ALTER TABLE public.envanter OWNER TO postgres;

--
-- Name: envanter_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.envanter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.envanter_id_seq OWNER TO postgres;

--
-- Name: envanter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.envanter_id_seq OWNED BY public.envanter.id;


--
-- Name: firms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.firms (
    id integer NOT NULL,
    firma_adi character varying(255) NOT NULL,
    yetkili_ad_soyad character varying(100),
    telefon character varying(20),
    faks character varying(20),
    vergi_no character varying(50),
    eposta character varying(100),
    adres text,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.firms OWNER TO postgres;

--
-- Name: firms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.firms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.firms_id_seq OWNER TO postgres;

--
-- Name: firms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.firms_id_seq OWNED BY public.firms.id;


--
-- Name: kasa_islemleri; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kasa_islemleri (
    id integer NOT NULL,
    islem_yonu character varying(50) NOT NULL,
    kategori character varying(100) NOT NULL,
    tutar numeric(10,2) NOT NULL,
    aciklama text,
    baglanti_id integer,
    islem_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    islem_yapan character varying(100),
    servis_no character varying(20)
);


ALTER TABLE public.kasa_islemleri OWNER TO postgres;

--
-- Name: kasa_islemleri_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.kasa_islemleri_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.kasa_islemleri_id_seq OWNER TO postgres;

--
-- Name: kasa_islemleri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.kasa_islemleri_id_seq OWNED BY public.kasa_islemleri.id;


--
-- Name: material_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.material_requests (
    id integer NOT NULL,
    service_id integer,
    usta_email character varying(100),
    part_name character varying(100) NOT NULL,
    quantity integer DEFAULT 1,
    description text,
    status character varying(50) DEFAULT 'Bekliyor'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    stok_girisi_yapildi_mi boolean DEFAULT false
);


ALTER TABLE public.material_requests OWNER TO postgres;

--
-- Name: material_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.material_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.material_requests_id_seq OWNER TO postgres;

--
-- Name: material_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.material_requests_id_seq OWNED BY public.material_requests.id;


--
-- Name: price_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.price_history (
    id integer NOT NULL,
    inventory_id integer,
    eski_alis numeric(10,2),
    yeni_alis numeric(10,2),
    eski_satis numeric(10,2),
    yeni_satis numeric(10,2),
    degisim_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.price_history OWNER TO postgres;

--
-- Name: price_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.price_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.price_history_id_seq OWNER TO postgres;

--
-- Name: price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.price_history_id_seq OWNED BY public.price_history.id;


--
-- Name: service_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_notes (
    id integer NOT NULL,
    service_id integer,
    note_text text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.service_notes OWNER TO postgres;

--
-- Name: service_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_notes_id_seq OWNER TO postgres;

--
-- Name: service_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_notes_id_seq OWNED BY public.service_notes.id;


--
-- Name: service_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_records (
    id integer NOT NULL,
    customer_id integer,
    device_id integer,
    fault_description text NOT NULL,
    status character varying(50) DEFAULT 'Kayıt Açıldı'::character varying,
    technician_note text,
    price numeric(10,2) DEFAULT 0,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.service_records OWNER TO postgres;

--
-- Name: service_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_records_id_seq OWNER TO postgres;

--
-- Name: service_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_records_id_seq OWNED BY public.service_records.id;


--
-- Name: service_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_status_history (
    id integer NOT NULL,
    service_id integer,
    old_status text,
    new_status text,
    changed_by text,
    note text,
    changed_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.service_status_history OWNER TO postgres;

--
-- Name: service_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_status_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_status_history_id_seq OWNER TO postgres;

--
-- Name: service_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_status_history_id_seq OWNED BY public.service_status_history.id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services (
    id integer NOT NULL,
    device_id integer,
    issue_text text NOT NULL,
    status text DEFAULT 'KabulEdildi'::text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    atanan_usta character varying(100),
    servis_no character varying(20),
    seri_no text,
    garanti text,
    musteri_notu text,
    offer_price numeric(10,2) DEFAULT 0,
    expert_note text,
    updated_at timestamp without time zone DEFAULT now(),
    customer_id integer,
    firm_id integer,
    yonetici_notu text
);


ALTER TABLE public.services OWNER TO postgres;

--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.services_id_seq OWNER TO postgres;

--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: servis_detay; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.servis_detay AS
 SELECT s.id,
    s.servis_no AS plaka,
        CASE
            WHEN (s.status = 'Pasif'::text) THEN 'PASIF / ARSIV'::text
            ELSE s.status
        END AS durum,
    s.issue_text AS ariza,
    s.atanan_usta AS usta,
    COALESCE(c.name, (f.firma_adi)::text, 'Bilinmeyen Firma/Müşteri'::text) AS musteri_adi,
    COALESCE(c.phone, (f.telefon)::text, '-'::text) AS telefon,
    d.cihaz_turu AS cihaz_tipi,
    concat(d.brand, ' ', d.model) AS marka_model,
    d.serial_no AS seri_no,
    d.garanti_durumu AS garanti,
    s.musteri_notu AS eklenen_notlar,
    to_char(s.created_at, 'DD.MM.YYYY HH24:MI'::text) AS tarih
   FROM (((public.services s
     JOIN public.devices d ON ((s.device_id = d.id)))
     LEFT JOIN public.customers c ON ((d.customer_id = c.id)))
     LEFT JOIN public.firms f ON ((d.firm_id = f.id)));


ALTER VIEW public.servis_detay OWNER TO postgres;

--
-- Name: shop_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shop_settings (
    id integer NOT NULL,
    key_name character varying(50),
    value_text character varying(255)
);


ALTER TABLE public.shop_settings OWNER TO postgres;

--
-- Name: shop_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shop_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shop_settings_id_seq OWNER TO postgres;

--
-- Name: shop_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shop_settings_id_seq OWNED BY public.shop_settings.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(100) NOT NULL,
    password character varying(100) NOT NULL,
    role character varying(20) DEFAULT 'admin'::character varying
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_rehber; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_rehber AS
 SELECT customers.id,
    customers.name,
    customers.phone,
    'bireysel'::text AS tip
   FROM public.customers
UNION ALL
 SELECT firms.id,
    firms.firma_adi AS name,
    firms.telefon AS phone,
    'firma'::text AS tip
   FROM public.firms;


ALTER VIEW public.v_rehber OWNER TO postgres;

--
-- Name: appointments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ALTER COLUMN id SET DEFAULT nextval('public.appointments_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: devices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices ALTER COLUMN id SET DEFAULT nextval('public.devices_id_seq'::regclass);


--
-- Name: envanter id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.envanter ALTER COLUMN id SET DEFAULT nextval('public.envanter_id_seq'::regclass);


--
-- Name: firms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.firms ALTER COLUMN id SET DEFAULT nextval('public.firms_id_seq'::regclass);


--
-- Name: kasa_islemleri id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kasa_islemleri ALTER COLUMN id SET DEFAULT nextval('public.kasa_islemleri_id_seq'::regclass);


--
-- Name: material_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material_requests ALTER COLUMN id SET DEFAULT nextval('public.material_requests_id_seq'::regclass);


--
-- Name: price_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price_history ALTER COLUMN id SET DEFAULT nextval('public.price_history_id_seq'::regclass);


--
-- Name: service_notes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_notes ALTER COLUMN id SET DEFAULT nextval('public.service_notes_id_seq'::regclass);


--
-- Name: service_records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_records ALTER COLUMN id SET DEFAULT nextval('public.service_records_id_seq'::regclass);


--
-- Name: service_status_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_status_history ALTER COLUMN id SET DEFAULT nextval('public.service_status_history_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: shop_settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_settings ALTER COLUMN id SET DEFAULT nextval('public.shop_settings_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointments (id, customer_id, device_id, appointment_date, appointment_time, assigned_usta, issue_text, status, is_confirmed, created_at, servis_no, firm_id, price, usta_notu, usta_maliyet, tahsil_edilen_tutar, mali_onay_durumu, yonetici_notu) FROM stdin;
6	1	\N	2026-03-28	15:00:00	Usta 1	Adres: Hshshs\nNot: Gagshs	İptal Edildi	f	2026-03-18 12:55:55.513405	26031802	\N	0.00	\N	0.00	0.00	f	\N
7	1	\N	2026-03-31	18:00:00	Usta 1	Adres: Trabzon\nNot: Ekmek al	İptal Edildi	f	2026-03-18 12:57:24.363681	26031803	\N	0.00	\N	0.00	0.00	f	\N
8	7	\N	2026-03-30	11:00:00	Usta 1	Adres: Eskisehir larnaka sk elif apt no10\nNot: Kirmizi ev	İptal Edildi	f	2026-03-18 13:06:06.535377	26031804	\N	0.00	\N	0.00	0.00	f	\N
9	9	\N	2026-03-23	10:00:00	Usta 1	📍 ADRES: Yukari mah asagi sk ege apt no10\n\n📝 NOT: Kirmizi boyali ev	İptal Edildi	f	2026-03-18 13:16:19.624758	26031805	\N	0.00	\N	0.00	0.00	f	\N
10	1	\N	2026-03-25	09:00:00	Usta 1	📍 ADRES: Kale male sale\n📝 NOT: Sari ev	İptal Edildi	f	2026-03-18 13:24:13.753927	26031806	\N	0.00	\N	0.00	0.00	f	\N
11	9	\N	2026-03-28	19:00:00	Usta 1	📍 ADRES: Kayra apt etimesgut ankara\n📝 NOT: Yesil ev	İptal Edildi	f	2026-03-18 13:36:11.569422	26031807	\N	0.00	\N	0.00	0.00	f	\N
12	1	\N	2026-03-19	23:00:00	Usta 1	📍 ADRES: Vsbshsh\n📝 NOT: Hsbdhdhd	İptal Edildi	f	2026-03-18 14:06:08.308113	26031808	\N	0.00	\N	0.00	0.00	f	\N
13	1	\N	2026-03-26	11:00:00	Usta 1	📍 ADRES: Bshdh\n📝 NOT: Gshshdh	İptal Edildi	f	2026-03-18 14:24:35.356147	26031809	\N	0.00	\N	0.00	0.00	f	\N
14	9	\N	2026-03-20	10:00:00	Usta 1	📍 ADRES: Varvar\n📝 NOT: R1	İptal Edildi	f	2026-03-18 14:40:12.391455	26031810	\N	0.00	\N	0.00	0.00	f	\N
15	9	\N	2026-03-26	24:00:00	Usta 1	📍 ADRES: B7\n📝 NOT: B7	İptal Edildi	f	2026-03-18 15:56:36.438952	26031815	\N	0.00	\N	0.00	0.00	f	\N
16	1	\N	2026-04-02	11:00:00	Usta 1	📍 ADRES: B8\n📝 NOT: B8	İptal Edildi	f	2026-03-18 16:04:04.720913	26031816	\N	0.00	\N	0.00	0.00	f	\N
17	7	\N	2026-04-10	10:00:00	Usta 1	📍 ADRES: B11\n📝 NOT: B11	İptal Edildi	f	2026-03-18 16:05:37.557181	26031818	\N	0.00	\N	0.00	0.00	f	\N
18	6	\N	2026-04-24	10:00:00	Usta 1	📍 ADRES: B13\n📝 NOT: B13	İptal Edildi	f	2026-03-18 16:13:39.689599	26031819	\N	0.00	\N	0.00	0.00	f	\N
19	5	\N	2026-04-16	10:00:00	Usta 1	📍 ADRES: B14\n📝 NOT: B14	İptal Edildi	f	2026-03-18 16:16:08.098327	26031820	\N	0.00	\N	0.00	0.00	f	\N
20	4	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: C2\n📝 NOT: C2	İptal Edildi	f	2026-03-18 16:29:20.240465	26031822	\N	0.00	\N	0.00	0.00	f	\N
21	4	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: C3\n📝 NOT: C3	İptal Edildi	f	2026-03-18 16:30:32.535159	26031823	\N	0.00	\N	0.00	0.00	f	\N
22	9	\N	2026-03-20	00:00:00	Usta 1	📍 ADRES: Z3\n📝 NOT: Z3	İptal Edildi	f	2026-03-18 16:38:23.657573	26031825	\N	0.00	\N	0.00	0.00	f	\N
23	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Z5\n📝 NOT: Z5	İptal Edildi	f	2026-03-18 16:40:51.164206	26031826	\N	0.00	\N	0.00	0.00	f	\N
24	4	\N	2026-03-20	11:11:00	Usta 1	📍 ADRES: 4\n📝 NOT: 4	İptal Edildi	f	2026-03-18 16:43:48.421333	26031829	\N	0.00	\N	0.00	0.00	f	\N
25	7	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Q2\n📝 NOT: Q2	İptal Edildi	f	2026-03-18 16:52:49.34655	26031830	\N	0.00	\N	0.00	0.00	f	\N
26	1	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: T1\n📝 NOT: T1	İptal Edildi	f	2026-03-18 16:54:20.874073	26031831	\N	0.00	\N	0.00	0.00	f	\N
27	1	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: Y1\n📝 NOT: Y1	İptal Edildi	f	2026-03-18 17:32:05.567049	26031832	\N	0.00	\N	0.00	0.00	f	\N
28	4	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: La3\n📝 NOT: La3	İptal Edildi	f	2026-03-18 17:45:38.002183	26031835	\N	0.00	\N	0.00	0.00	f	\N
29	6	\N	2026-03-27	05:00:00	Usta 1	📍 ADRES: Hdhdbd\n📝 NOT: Hxhxhdh	İptal Edildi	f	2026-03-18 17:58:39.394776	26031837	\N	0.00	\N	0.00	0.00	f	\N
30	9	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: Yeni\n📝 NOT: Yeni	İptal Edildi	f	2026-03-18 18:19:13.48068	26031839	\N	0.00	\N	0.00	0.00	f	\N
31	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Ll\n📝 NOT: Ll	İptal Edildi	f	2026-03-18 18:43:17.522278	26031841	\N	0.00	\N	0.00	0.00	f	\N
32	9	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Ll\n📝 NOT: Ll	İptal Edildi	f	2026-03-18 18:44:51.279754	26031842	\N	0.00	\N	0.00	0.00	f	\N
33	9	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Son\n📝 NOT: Son	İptal Edildi	f	2026-03-18 19:00:01.825133	26031844	\N	0.00	\N	0.00	0.00	f	\N
34	9	\N	2026-03-28	11:00:00	Usta 1	📍 ADRES: Hshdhd\n📝 NOT: Hsbshdh	İptal Edildi	f	2026-03-18 19:19:53.561712	26031846	\N	0.00	\N	0.00	0.00	f	\N
35	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Kayseri melikgazi\n🔧 CİHAZ: Masa ustu bilgisayar Hp Ts10/agc_7\n📝 NOT: Sicak kablo yok	İptal Edildi	f	2026-03-18 21:00:03.910399	26031847	\N	0.00	\N	0.00	0.00	f	\N
36	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:03.097398	26031901	\N	0.00	\N	0.00	0.00	f	\N
37	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:05.148869	26031902	\N	0.00	\N	0.00	0.00	f	\N
38	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:06.14883	26031903	\N	0.00	\N	0.00	0.00	f	\N
39	9	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Gsbsjs\n🔧 CİHAZ: Hshshdh Gshsbdbxb Hdhdjdjfjjfjfjdjdjdjd\n📝 NOT: Kac1	İptal Edildi	f	2026-03-19 16:01:49.077263	26031904	\N	0.00	\N	0.00	0.00	f	\N
40	1	\N	2026-03-27	11:11:00	Usta 1	📍 ADRES: Ggggg\n🔧 CİHAZ: Gggg Gggg Tggg\n📝 NOT: Fddddddddee	İptal Edildi	f	2026-03-19 16:11:58.120491	26031907	\N	0.00	\N	0.00	0.00	f	\N
41	1	\N	2026-03-28	11:00:00	Usta 1	📍 ADRES: Hshsj\n🔧 CİHAZ: Jshshs Jshsh Jsjdjdj\n📝 NOT: Bsbsvsh	İptal Edildi	f	2026-03-19 18:17:35.046828	26031908	\N	0.00	\N	0.00	0.00	f	\N
42	\N	\N	2026-03-26	11:00:00	Usta 1	📍 ADRES: Bshshs\n🔧 CİHAZ: Hshshsh Hwhshdh Jshdhdh\n📝 NOT: Nsbsbdh	İptal Edildi	f	2026-03-19 18:21:26.722197	26031911	11	0.00	\N	0.00	0.00	f	\N
43	3	\N	2026-03-27	11:00:00	Usta 1	📍 ADRES: Hhshsb\n🔧 CİHAZ: Hshhs Hshs Hshs\n📝 NOT: Snnshs	İptal Edildi	f	2026-03-19 18:24:53.194704	26031912	\N	0.00	\N	0.00	0.00	f	\N
44	\N	\N	2026-03-27	11:00:00	Usta 1	📍 ADRES: Hwhehd\n🔧 CİHAZ: Hshdh Hshdh Jdhdj\n📝 NOT: Hshdh	İptal Edildi	f	2026-03-19 18:25:31.079071	26031913	6	0.00	\N	0.00	0.00	f	\N
45	1	\N	2026-03-25	11:00:00	Usta 1	📍 ADRES: Bshshsj\n🔧 CİHAZ: Jshsh Hshsh Hshsh\n📝 NOT: Bsbsbshs	İptal Edildi	f	2026-03-19 18:58:57.98919	26031914	\N	0.00	\N	0.00	0.00	f	\N
46	9	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Vsgdgdhs\n🔧 CİHAZ: Hdhdhd Jdhdhdj Hdhdhdh\n📝 NOT: Bsbdbdhdj	İptal Edildi	f	2026-03-19 19:05:22.413085	26031915	\N	0.00	\N	0.00	0.00	f	\N
47	1	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: Jejdjd\n🔧 CİHAZ: Hehdhdh Ndhdjd Jdjdjd\n📝 NOT: Jsjdjdj	İptal Edildi	f	2026-03-19 19:06:55.301721	26031916	\N	0.00	\N	0.00	0.00	f	\N
48	\N	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: Bshshs\n🔧 CİHAZ: Jshshdh Jshshd Jdhdhdh\n📝 NOT: Bxbxbxh	İptal Edildi	f	2026-03-19 19:15:14.887685	26031917	4	0.00	\N	0.00	0.00	f	\N
51	6	\N	2026-03-19	23:59:00	Usta 1	📍 ADRES: Bdjdnd\n🔧 CİHAZ: Hdhdjd Hdhdhf Hdhdhd\n📝 NOT: Bdbxbxbxb	Teslim Edildi	f	2026-03-19 23:58:19.907416	26031920	\N	5000.00		0.00	0.00	f	\N
49	\N	\N	2026-03-29	11:00:00	Usta 1	📍 ADRES: Bshdhdh\n🔧 CİHAZ: Hehdhdjfjf Hdhdhdhd Jdhdjdjdj\n📝 NOT: Hshdhdjd	İptal Edildi	f	2026-03-19 19:40:45.995698	26031918	3	0.00	\N	0.00	0.00	f	\N
52	11	\N	2026-03-29	13:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Tel Sony Q1\n📝 NOT: Randevu 1	Teslim Edildi	f	2026-03-20 17:29:34.201166	26032004	\N	9000.00	Yes	0.00	0.00	f	\N
53	\N	\N	2026-03-29	14:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Cep Sanyo 1q\n📝 NOT: Arda 2 olsun firma randuvu	Teslim Edildi	f	2026-03-20 17:30:48.449133	26032005	12	9999.00	Dokuz	0.00	0.00	f	\N
54	\N	\N	2026-03-31	12:00:00	Usta 1	📍 ADRES: Cingen mah. Beytepe sk. Gul apt. Cincin / baglar/ ankara\n🔧 CİHAZ: Klavye Pirhana Zz10\n📝 NOT: Burasi not bolumu	Teslim Edildi	f	2026-03-20 18:35:30.263775	26032007	12	2500.00	Takip	0.00	0.00	f	\N
50	\N	\N	2026-03-29	12:00:00	Usta 1	📍 ADRES: Jsjdjd\n🔧 CİHAZ: Hdhdh Jdhdhf Hdhdhd\n📝 NOT: Hshshdhndbshs	Teslim Edildi	f	2026-03-19 20:08:46.7787	26031919	2	2500.00	Tamam	0.00	0.00	f	\N
55	\N	\N	2026-03-24	10:00:00	Usta 1	📍 ADRES: Ggg\n🔧 CİHAZ: T T T\n📝 NOT: Kirmizi	Teslim Edildi	f	2026-03-22 22:19:03.151624	26032203	1	40000.00	Hayda	0.00	0.00	f	\N
58	\N	\N	2026-03-29	14:00:00	Usta 1	📍 ADRES: Hehehrjrjr\n🔧 CİHAZ: Jeueuruf Jrjrjrjf Jejdjfjf\n📝 NOT: Bshdhdhd	Teslim Edildi	f	2026-03-23 21:56:22.597304	26032316	12	1001.00	gece	0.00	0.00	f	\N
80	11	\N	2026-03-27	14:30:00	Usta 1	📍 ADRES: Ihuguu\n🔧 CİHAZ: Ggg Ggg Ghh\n📝 NOT: Hh	Kapatıldı	f	2026-03-25 15:59:45.205765	26032511	\N	999.00	Vb	999.00	1499.00	f	\N
59	11	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: ,kgxoydiyd\n🔧 CİHAZ: Ig igxiyx Ohxigxiyxiyc T8xiyciyx8y\n📝 NOT: U9cohciyc8y	Teslim Edildi	f	2026-03-24 20:30:46.664623	26032421	\N	1010.00	ddc	0.00	0.00	f	\N
57	11	\N	2026-03-29	13:00:00	Usta 1	📍 ADRES: Jehdhd\n🔧 CİHAZ: Bshshd Nshshsh Hshdhdh\n📝 NOT: Jebdhdbd	Teslim Edildi	f	2026-03-23 21:55:18.40494	26032315	\N	1005.00	sıuwhdıu	0.00	0.00	f	\N
56	\N	\N	2026-03-25	10:00:00	Usta 1	📍 ADRES: Hshdhd\n🔧 CİHAZ: Simens Hh H\n📝 NOT: Dbdhdhxh	Teslim Edildi	f	2026-03-23 21:02:30.04677	26032314	11	8050.00	Gggg	0.00	0.00	f	\N
65	\N	\N	2026-03-31	10:00:00	Usta 1	📍 ADRES: Yvyv7c\n🔧 CİHAZ: Ctc6c6c 7vuv7 Yvuvuv\n📝 NOT: Ibvuv	Teslim Edildi	f	2026-03-24 22:06:42.928118	26032429	11	4545.00	Vyvuc	0.00	0.00	f	\N
64	2	\N	2026-03-30	10:00:00	Usta 1	📍 ADRES: Vuvuv7\n🔧 CİHAZ: Uv7g7h Ucuv7g Vuv7g\n📝 NOT: Uvuvuv	Teslim Edildi	f	2026-03-24 21:54:34.683335	26032428	\N	833838.00	Uvubuv	0.00	0.00	f	\N
63	8	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Tygh\n🔧 CİHAZ: Yyhuuu Yuj Huj\n📝 NOT: Hhhu	Teslim Edildi	f	2026-03-24 21:21:51.664817	26032427	\N	60686.00	Ychc	0.00	0.00	f	\N
62	\N	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Hvuvuv\n🔧 CİHAZ: Yv7v7v Yvyvyc6c 6vg6g6c\n📝 NOT: Vuvuvuvu	Teslim Edildi	f	2026-03-24 21:12:04.786405	26032424	11	5558.00	Ghhh	0.00	0.00	f	\N
70	\N	\N	2026-03-26	15:00:00	Usta 1	📍 ADRES: Ggggh\n🔧 CİHAZ: Gtg Ggh Gh\n📝 NOT: Gggh	Teslim Edildi	f	2026-03-24 23:07:12.539821	26032434	4	12.00	Cc	12.00	18.00	f	\N
61	\N	\N	2026-03-27	11:00:00	Usta 1	📍 ADRES: Ghehrhrh\n🔧 CİHAZ: Hehrhru Hehdhd Hehfhfj\n📝 NOT: Iyc8yc8yc	Teslim Edildi	f	2026-03-24 20:58:22.588418	26032423	4	1500.00	Gghj	0.00	0.00	f	\N
60	\N	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Uvub8h\n🔧 CİHAZ: 7gibub 7vibub Iguv7v7v\n📝 NOT: Uvuvuvuv	Teslim Edildi	f	2026-03-24 20:53:54.924946	26032422	6	1111.00	vvdv	0.00	0.00	f	\N
79	\N	\N	2026-03-29	19:00:00	Usta 1	📍 ADRES: Uzak sk geri cd. Yuksek no1\n🔧 CİHAZ: Tablet Sony 11a\n📝 NOT: Cok calis isler fazla dikatli ol	Kapatıldı	f	2026-03-25 13:28:36.550169	26032510	2	2222.00	U.notu burada	2222.00	3333.00	f	\N
66	10	\N	2026-03-31	11:00:00	Usta 1	📍 ADRES: Jvivig\n🔧 CİHAZ: Ugugi 7f7g7 Ig8g8\n📝 NOT: U uvug	Teslim Edildi	f	2026-03-24 22:11:45.129487	26032430	\N	505.00	Gg	0.00	0.00	f	\N
67	\N	\N	2026-03-31	15:00:00	Usta 1	📍 ADRES: Viv8v8\n🔧 CİHAZ: 8g8g 8g8g8g Ig8g7g\n📝 NOT: Igiv8g	Teslim Edildi	f	2026-03-24 22:17:33.260912	26032431	5	1900.00	ddddcc	0.00	0.00	f	\N
78	\N	\N	2026-03-28	18:00:00	Usta 1	📍 ADRES: Bshsh\n🔧 CİHAZ: Hshdh Hshsh Hdhdh\n📝 NOT: Hshdh	Kapatıldı	f	2026-03-25 12:55:22.620513	26032509	11	1001.00	Bshsh	1001.00	1502.00	f	\N
77	\N	\N	2026-03-29	17:00:00	Usta 1	📍 ADRES: Jdhdj\n🔧 CİHAZ: Ndjdj Jshdh Ndndn\n📝 NOT: Hshshd	Kapatıldı	f	2026-03-25 12:50:23.729549	26032508	2	1001.00	Bbb	0.00	0.00	f	\N
76	\N	\N	2026-03-28	17:00:00	Usta 1	📍 ADRES: Bubu\n🔧 CİHAZ: 7guv 7g7g 7h7h\n📝 NOT: Ubb7u	Kapatıldı	f	2026-03-25 11:33:05.264014	26032506	12	1555.00	Vbh	5.00	8.00	f	\N
68	7	\N	2026-03-30	10:00:00	Usta 1	📍 ADRES: J̌ehehe\n🔧 CİHAZ: Jjshs Hshsh Hshsh\n📝 NOT: Hsgdhdhhd	Teslim Edildi	f	2026-03-24 22:23:00.95398	26032432	\N	1.00	Rr	0.00	0.00	f	\N
69	\N	\N	2026-03-30	12:00:00	Usta 1	📍 ADRES: Uvycuc\n🔧 CİHAZ: C6c6f Ucucu J uvuv\n📝 NOT: Fyyc	Teslim Edildi	f	2026-03-24 22:51:50.954374	26032433	8	1009.00	Ggv	0.00	0.00	f	\N
71	\N	\N	2026-03-20	11:00:00	Usta 1	📍 ADRES: fdgdfg\n🔧 CİHAZ: fdgdfg dgdfgdfg dfgg\n📝 NOT: fdgfd	Teslim Edildi	f	2026-03-25 10:25:43.739687	26032501	9	223.00	we	0.00	0.00	f	\N
72	\N	\N	2026-03-31	12:00:00	Usta 1	📍 ADRES: Iyx8yx8yd86\n🔧 CİHAZ: Yxycucu 7ffuf Ufuf7\n📝 NOT: Ariza var	Teslim Edildi	f	2026-03-25 10:29:20.668778	26032502	11	1000.00	usta derki	0.00	0.00	f	\N
73	1	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Hdhdh\n🔧 CİHAZ: Hshdh Hshdh Hehdhd\n📝 NOT: Hh	Teslim Edildi	f	2026-03-25 10:39:48.092718	26032503	\N	1000.00	qqq	500.00	750.00	f	\N
74	\N	\N	2026-03-29	14:50:00	Usta 1	📍 ADRES: Ggh\n🔧 CİHAZ: Ttg Ghh Ggh\n📝 NOT: Ghgg	Teslim Edildi	f	2026-03-25 11:13:18.25513	26032504	8	555.00	Ggg	0.00	0.00	f	\N
75	\N	\N	2026-03-28	15:00:00	Usta 1	📍 ADRES: Buuv\n🔧 CİHAZ: 7g8g Ug7g Iviv\n📝 NOT: Hcuc	Teslim Edildi	f	2026-03-25 11:24:48.784154	26032505	12	8000.00	Yg	0.00	0.00	f	\N
82	\N	\N	2026-04-04	10:00:00	Usta 1	📍 ADRES: Garaj\n🔧 CİHAZ: Tv Sam Sun\n📝 NOT: Ransevu	Kapatıldı	f	2026-03-25 18:49:31.5449	26032514	11	1000.00		1000.00	1500.00	f	\N
81	\N	\N	2026-03-28	15:00:00	Usta 1	📍 ADRES: Ggg\n🔧 CİHAZ: Ggh Ggg Ggg\n📝 NOT: Jhj	Kapatıldı	f	2026-03-25 16:00:11.174857	26032512	12	9991.00	Ccc	9991.00	14987.00	f	\N
83	\N	\N	2026-04-04	10:00:00	Usta 1	📍 ADRES: Q\n🔧 CİHAZ: Q Q Q\n📝 NOT: Hsbsbs	Teslim Edildi	f	2026-03-25 23:50:28.360899	26032517	4	10.00	g	0.00	0.00	f	\N
84	\N	\N	2026-04-04	11:00:00	Usta 1	📍 ADRES: Hshdj\n🔧 CİHAZ: Uwheh Jeheh Jwjej\n📝 NOT: Hhh	Kapatıldı	f	2026-03-25 23:52:29.227174	26032519	2	5.00	Fgg	5.00	8.00	f	\N
85	11	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: H\n🔧 CİHAZ: Y H U\n📝 NOT: R	Teslim Edildi	f	2026-03-26 09:47:38.920741	26032601	\N	101.00	Vgh	0.00	0.00	f	\N
88	\N	\N	2026-03-29	17:00:00	Usta 1	📍 ADRES: Hsjs\n🔧 CİHAZ: Jsjs Djjd Jdjd\n📝 NOT: Nsbzj	Teslim Edildi	f	2026-03-26 13:23:00.180774	26032605	11	94989.00	Jsjd\n	11.00	17.00	f	\N
89	\N	\N	2026-03-29	23:00:00	Usta 1	📍 ADRES: Jehdhd\n🔧 CİHAZ: Jsjdh Jsjdj Jdjdjd\n📝 NOT: Jejdj	Teslim Edildi	f	2026-03-26 13:27:10.636368	26032606	1	15.00		15.00	23.00	f	\N
86	\N	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Hdhdj\n🔧 CİHAZ: Hshdhd Hshs Hshsh\n📝 NOT: Gg	Teslim Edildi	f	2026-03-26 10:33:06.9946	26032602	6	669.00	Tt	0.00	0.00	f	\N
87	\N	\N	2026-03-28	18:00:00	Usta 1	📍 ADRES: Ggh\n🔧 CİHAZ: Ttg Vgv Vvv\n📝 NOT: Vvh	Teslim Edildi	f	2026-03-26 13:17:01.988935	26032603	8	2.00		0.00	0.00	f	\N
90	\N	\N	2026-03-31	11:00:00	Usta 1	📍 ADRES: Hehdhd\n🔧 CİHAZ: Jsjdj Hdhdhd Jdjdj\n📝 NOT: Hdhdhdh	Teslim Edildi	f	2026-03-26 13:37:11.079052	26032608	1	10.00		10.00	15.00	f	\N
91	11	\N	2026-03-31	18:30:00	Usta 1	📍 ADRES: Ghh\n🔧 CİHAZ: Gyu Hhu Hhh\n📝 NOT: Vhhh	İptal Edildi	f	2026-03-26 13:44:04.0035	26032609	\N	0.00	\N	0.00	0.00	f	\N
92	11	\N	2026-03-29	18:00:00	Usta 1	📍 ADRES: Q\n🔧 CİHAZ: Q Q Q\n📝 NOT: H	İptal Edildi	f	2026-03-26 13:59:17.068525	26032610	\N	111.00	111	0.00	0.00	f	\N
93	\N	\N	2026-03-29	19:00:00	Usta 1	📍 ADRES: Bhhh\n🔧 CİHAZ: Gyh Ggh Ggy\n📝 NOT: Bhj	Teslim Edildi	f	2026-03-26 14:21:15.312637	26032611	2	444.00	G	444.00	666.00	f	\N
94	1	\N	2026-03-27	23:00:00	Usta 1	📍 ADRES: Hdhdj\n🔧 CİHAZ: Hshdh Jsjdj Nsjdj\n📝 NOT: Jshdh	İptal Edildi	f	2026-03-26 15:47:21.604707	26032612	\N	501.00	H	501.00	752.00	f	\N
103	\N	\N	2026-03-27	19:00:00	Usta 1	📍 ADRES: Bbb\n🔧 CİHAZ: Ggg Gg Hg\n📝 NOT: Ghh	Teslim Edildi	f	2026-03-26 19:34:15.129582	26032623	12	556.00		556.00	834.00	f	\N
109	\N	\N	2026-03-28	11:00:00	Usta 1	📍 ADRES: Ndhdh\n🔧 CİHAZ: Lab Q Q\n📝 NOT: Arizali	Teslim Edildi	f	2026-03-31 14:08:35.10374	26033102	12	11000.00	Kasa	11000.00	16500.00	f	\N
97	\N	\N	2026-03-27	18:00:00	Usta 1	📍 ADRES: Ɓhhwn\n🔧 CİHAZ: J2j2 N3j3 J3j3j\n📝 NOT: Gyh	İptal Edildi	f	2026-03-26 16:59:42.708575	26032617	4	1.00	1	0.00	0.00	f	\N
96	\N	\N	2026-03-26	18:00:00	Usta 1	📍 ADRES: Jrjrj\n🔧 CİHAZ: Jejdj Jejd Jejrj\n📝 NOT: Jejrj	İptal Edildi	f	2026-03-26 16:48:34.102004	26032614	7	333.00	B	333.00	500.00	f	\N
104	1	\N	2026-03-07	10:00:00	Usta 1	📍 ADRES: Ugu\n🔧 CİHAZ: Ivuv 8bib Ibib\n📝 NOT: Uvvuv	Teslim Edildi	f	2026-03-26 20:25:42.546951	26032624	\N	200.00	Vv	200.00	300.00	f	\N
125	\N	\N	2026-04-30	12:00:00	Usta 1	📍 ADRES: Deniz evler baba golcuk bolu\n🔧 CİHAZ: notebook hp vito1000\n📝 NOT: pili bozuk	İptal Edildi	f	2026-04-09 19:24:02.304867	26040907	15	0.00	\N	0.00	0.00	f	\N
99	\N	\N	2026-04-17	12:00:00	Usta 1	📍 ADRES: Hwhej\n🔧 CİHAZ: Jwueh Iejej Iejej\n📝 NOT: Nsnsn	İptal Edildi	f	2026-03-26 17:31:17.045779	26032619	11	505.00	R	505.00	758.00	f	\N
105	1	\N	2026-03-29	11:50:00	Usta 1	📍 ADRES: Hzhxh\n🔧 CİHAZ: Jdhxj Hdhd Jdjx\n📝 NOT: Hshdh	Teslim Edildi	f	2026-03-26 23:49:19.883041	26032625	\N	9464.00	U2hw	9464.00	14196.00	f	\N
98	\N	\N	2026-04-24	10:00:00	Usta 1	📍 ADRES: Uejdjd\n🔧 CİHAZ: Ieiei Krjrk Jejri\n📝 NOT: Ndnfnf	İptal Edildi	f	2026-03-26 17:28:52.503445	26032618	7	1.00	1	0.00	0.00	f	\N
110	\N	\N	2026-03-28	19:00:00	Usta 1	📍 ADRES: Hahsh\n🔧 CİHAZ: Hahaha Haha Haha\n📝 NOT: Hahah	Teslim Edildi	f	2026-03-31 14:12:38.82726	26033104	12	22000.00	Hshe	22000.00	33000.00	f	\N
115	\N	\N	2026-04-23	10:00:00	Usta 1	📍 ADRES: Jsjdjd\n🔧 CİHAZ: Lab Son Fon\n📝 NOT: Sari lale	Teslim Edildi	f	2026-04-05 16:15:01.555905	26040506	2	5000.00	Ham fiyat	5000.00	7500.00	f	\N
100	\N	\N	2026-04-02	10:00:00	Usta 1	📍 ADRES: Djdjdj\n🔧 CİHAZ: Ndndj Jdjdjd Jdjdj\n📝 NOT: Nbb	Teslim Edildi	f	2026-03-26 17:37:28.516656	26032620	2	600.00		600.00	900.00	f	\N
111	\N	\N	2026-03-29	12:00:00	Usta 1	📍 ADRES: Jsjdj\n🔧 CİHAZ: Jshsh Jshs Jehdh\n📝 NOT: Jeheh	Teslim Edildi	f	2026-03-31 14:33:47.545408	26033106	2	8750.00	Gg	8750.00	13125.00	f	\N
106	\N	\N	2026-03-29	15:00:00	Usta 1	📍 ADRES: Yhhi\n🔧 CİHAZ: Uhh Ghh Ggh\n📝 NOT: Bhhj	Teslim Edildi	f	2026-03-27 00:32:48.619715	26032701	11	404.00		404.00	606.00	f	\N
102	\N	\N	2026-03-29	15:50:00	Usta 1	📍 ADRES: Jsjd\n🔧 CİHAZ: Nsjdj Jejd Jdjdj\n📝 NOT: Nshs	Teslim Edildi	f	2026-03-26 18:57:02.635168	26032622	5	6465.00	Jdj	6465.00	9698.00	f	\N
101	\N	\N	2026-03-29	11:30:00	Usta 1	📍 ADRES: Bsdj\n🔧 CİHAZ: Jdjd Hdhd Hdhd\n📝 NOT: Hshs	Teslim Edildi	f	2026-03-26 18:10:14.043392	26032621	6	555.00	Y5	555.00	833.00	f	\N
108	\N	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Yukarı mah. Sarı sk. Alma apt. No 5 elmadag ANKARA\n🔧 CİHAZ: Labtop Fuji F16\n📝 NOT: Cihazdan ses gelmiyor	Teslim Edildi	f	2026-03-30 18:37:53.28264	26033002	13	1570.00	İşlem tamam	1570.00	2355.00	f	\N
126	1	\N	2026-04-10	11:00:00	Usta 1	📍 ADRES: Atatürk Mah. 122. Sokak No:5 Gölcük/Kocaeli\n🔧 CİHAZ: notebook hp vito1000\n📝 NOT: TERRT	İptal Edildi	f	2026-04-09 20:22:50.384455	26040908	\N	2500.00	Vvv	2500.00	3750.00	f	\N
107	\N	\N	2026-03-29	14:20:00	Usta 1	📍 ADRES: Jcjfjf\n🔧 CİHAZ: Ueufj Hfjfjf Jejdjf\n📝 NOT: Jckgkf	Teslim Edildi	f	2026-03-28 15:02:45.890852	26032801	2	6666.00	Cam degisti	6666.00	9999.00	f	\N
113	\N	\N	2026-04-23	10:00:00	Usta 1	📍 ADRES: Baba adres ayni\n🔧 CİHAZ: Cep baba Sony 001\n📝 NOT: Kirmizi ev yani sari ev	Teslim Edildi	f	2026-04-04 14:14:15.914995	26040405	15	1200.00	kumanda değişti	1200.00	1800.00	f	\N
95	4	\N	2026-04-26	10:00:00	Usta 1	📍 ADRES: Hshd\n🔧 CİHAZ: Jsjdj Jdjd Jdjdj\n📝 NOT: Hshdh	İptal Edildi	f	2026-03-26 16:43:48.289904	26032613	\N	0.00	\N	0.00	0.00	f	aramalara cevap vermedi
112	\N	\N	2026-04-26	11:00:00	Usta 1	📍 ADRES: Jdjdj\n🔧 CİHAZ: Jejrj Jrjrj Jejdjd\n📝 NOT: Jeheh	Teslim Edildi	f	2026-04-04 11:31:55.871404	26040402	11	21000.00	Randevu 05	21000.00	31500.00	f	\N
123	\N	\N	2026-04-17	11:00:00	Usta 1	📍 ADRES: Denizevler ana golcuk baba\n🔧 CİHAZ: Bsbshz Jsbs Jsjs\n📝 NOT: Yandim ana	Teslim Edildi	f	2026-04-09 18:51:22.305524	26040905	14	1000.00	Son deneme	1000.00	1500.00	f	\N
127	13	\N	2026-04-24	15:00:00	Usta 1	📍 ADRES: Denizevler golcuk bolu\n🔧 CİHAZ: cep  hundai h26\n📝 NOT: web banyoya düştü	İptal Edildi	f	2026-04-10 18:20:07.143406	26041003	\N	0.00	\N	0.00	0.00	f	\N
124	15	\N	2026-04-23	11:00:00	Usta 1	📍 ADRES: uzun uzun kavaklar derinde kocaeli\n🔧 CİHAZ: Ggh Hgh Jh\n📝 NOT: Uhg	İptal Edildi	f	2026-04-09 19:03:31.504233	26040906	\N	0.00	\N	0.00	0.00	f	\N
122	\N	\N	2026-04-20	10:00:00	Usta 1	📍 ADRES: Gölcük, Kocaeli\n🔧 CİHAZ: Ugxigx8td Hkxutxyivoyxd Fufucc\n📝 NOT: G7ucicuc	Teslim Edildi	f	2026-04-07 15:51:19.919132	26040705	1	666.00	Gg	666.00	999.00	f	\N
121	\N	\N	2026-04-22	11:00:00	Usta 1	📍 ADRES: Sanayi Sitesi, Gölcük\n🔧 CİHAZ: Hhhhh Hhh Hgh\n📝 NOT: Vvft	Teslim Edildi	f	2026-04-07 15:43:33.691267	26040704	4	43000.00	Vvh	43000.00	64500.00	f	\N
119	\N	\N	2026-04-30	12:00:00	Usta 1	📍 ADRES: Yfkrj\n🔧 CİHAZ: Jejrh Hdhdh Jrjdj\n📝 NOT: Jrjrh	Teslim Edildi	f	2026-04-07 14:49:00.021607	26040702	14	1300.00	Bvcc	1300.00	1950.00	f	dönüş yapmadı
114	14	\N	2026-04-25	10:00:00	Usta 1	📍 ADRES: Cocuk2 ev adresi\n🔧 CİHAZ: Cep c2 Ericsonn T16\n📝 NOT: Sari evin yani kirmizi ev	Teslim Edildi	f	2026-04-04 14:15:40.661544	26040406	\N	7500.00	gg	7500.00	11250.00	f	PARASI ÜSTÜ VERİLECEK (1000) 
131	\N	\N	2026-04-15	11:00:00		ADRES: WEB4 | CİHAZ: cep  apple u17 | NOT: yeniden f web elma	İptal Edildi	f	2026-04-12 16:24:51.034866	26041207	\N	0.00	\N	0.00	0.00	f	\N
132	\N	\N	2026-04-15	12:00:00		📍 ADRES: WEB4\n🔧 CİHAZ: cep  apple u17\n📝 NOT: 3 . f web elma	İptal Edildi	f	2026-04-12 16:34:39.086889	26041208	\N	0.00	\N	0.00	0.00	f	\N
133	\N	\N	2026-04-30	11:00:00	Usta 1	📍 ADRES: Deniz evler baba golcuk bolu\n🔧 CİHAZ: Ggg Jdhdj Jdhdh\n📝 NOT: Bshdhd	İptal Edildi	f	2026-04-12 16:37:13.077498	26041209	15	0.00	\N	0.00	0.00	f	\N
134	\N	\N	2026-04-15	13:00:00		📍 ADRES: WEB4\n🔧 CİHAZ: cep  apple u17\n📝 NOT: 4 .f web elma	İptal Edildi	f	2026-04-12 16:47:48.869143	26041210	\N	0.00	\N	0.00	0.00	f	\N
135	\N	\N	2026-04-16	01:00:00		📍 ADRES: Denizevler ana golcuk baba\n🔧 CİHAZ: cep  apple vito1000\n📝 NOT: deneme	İptal Edildi	f	2026-04-12 16:49:21.2727	26041211	\N	0.00	\N	0.00	0.00	f	\N
136	\N	\N	2026-04-16	18:00:00		📍 ADRES: Denizevler ana golcuk baba\n🔧 CİHAZ: cep  apple h26\n📝 NOT: öffffffffffffffffffffffffff	İptal Edildi	f	2026-04-12 16:51:05.941472	26041212	14	0.00	\N	0.00	0.00	f	\N
137	\N	\N	2026-04-15	18:00:00		📍 ADRES: WEB4\n🔧 CİHAZ: cep  apple u17\n📝 NOT: son fweb	İptal Edildi	f	2026-04-12 16:55:46.185732	26041213	24	0.00	\N	0.00	0.00	f	\N
129	21	\N	2026-04-14	10:00:00		📍 ADRES: webb1\n\n\n\n🔧 CİHAZ: cep  apple u17\n📝 NOT: randevu1	İptal Edildi	f	2026-04-12 15:21:12.901681	26041205	\N	0.00	\N	0.00	0.00	f	\N
128	14	\N	2026-04-30	15:00:00	Usta 1	📍 ADRES: Deniz evler golcuk bolu2\n🔧 CİHAZ: Cep Hundai2 I26\n📝 NOT: Mobil kayit	İptal Edildi	f	2026-04-10 18:21:21.039734	26041004	\N	0.00	\N	0.00	0.00	f	
130	\N	\N	2026-04-15	10:00:00		📍 ADRES: WEB4\n🔧 CİHAZ: apple d17 1111\n📝 NOT: 	İptal Edildi	f	2026-04-12 15:30:36.130602	26041206	\N	0.00	\N	0.00	0.00	f	\N
138	1	\N	2026-04-24	12:00:00	Usta 1	📍 ADRES: Atatürk Mah. 122. Sokak No:5 Gölcük/Kocaeli\n🔧 CİHAZ: notebook apple 1111\n📝 NOT: herşey	İptal Edildi	f	2026-04-12 16:59:39.561388	26041214	\N	0.00	\N	0.00	0.00	f	\N
142	\N	\N	2026-04-19	10:00:00	Usta 1	📍 ADRES: WEB4\n🔧 CİHAZ: Cep Apple S17\n📝 NOT: F web elma 2	Teslim Edildi	f	2026-04-12 18:11:29.966933	26041218	24	12000.00	1218 fweb elma	12000.00	18000.00	f	TIKIR TIKIR 1
140	\N	\N	2026-04-18	12:00:00	Usta 1	📍 ADRES: Mobile4\n🔧 CİHAZ: Cep Apple B17\n📝 NOT: F mobile nar1	Teslim Edildi	f	2026-04-12 17:40:29.262832	26041216	22	48750.00	Agir bakim	48750.00	73125.00	f	\N
143	\N	\N	2026-04-19	10:00:00	Usta 1	📍 ADRES: Denizevler ana golcuk baba\n🔧 CİHAZ: cep  hp 1111\n📝 NOT: şikayet kutusu	Teslim Edildi	f	2026-04-12 23:17:42.750652	26041219	14	3333.00	Not girilmedi	3333.00	5000.00	f	\N
144	11	\N	2026-04-14	18:00:00	Usta 1	📍 ADRES: KANAVA LOJ ERDEK BALIKESİR TRABZON\n🔧 CİHAZ: cep  hundai j17\n📝 NOT: ikaz var mı\n	Teslim Edildi	f	2026-04-13 00:05:36.350786	26041301	\N	7500.00	Hehdh	7500.00	11250.00	f	\N
139	19	\N	2026-04-16	12:00:00	Usta 1	📍 ADRES: Mobile 1\n🔧 CİHAZ: cep  apple j17\n📝 NOT: b mobile nar 1	İptal Edildi	f	2026-04-12 17:37:40.916182	26041215	\N	0.00	\N	0.00	0.00	f	\N
141	21	\N	2026-04-17	12:00:00	Usta 1	📍 ADRES: webb1\n\n\n\n🔧 CİHAZ: cep  apple d17\n📝 NOT: b web elma  2	Teslim Edildi	f	2026-04-12 18:10:12.458359	26041217	\N	5555.00	Guruk	5555.00	8333.00	f	\N
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, name, phone, created_at, fax, email, address, musteri_turu) FROM stdin;
1	Ahmet Yılmaz	05441000011	2026-03-16 13:38:57.709668	02624111111	ahmet@gmail.com	Atatürk Mah. 122. Sokak No:5 Gölcük/Kocaeli	Bireysel
2	Mehmet Kaya	05441000012	2026-03-16 13:38:57.709668	02623222222	mehmet@hotmail.com	Hürriyet Cad. No:45 İzmit/Kocaeli	Bireysel
3	Ayşe Demir	05441000013	2026-03-16 13:38:57.709668	02624553333	ayse@outlook.com	Dumlupınar Mah. No:12 Karamürsel/Kocaeli	Bireysel
4	Fatma Çelik	05441000014	2026-03-16 13:38:57.709668	02622334444	fatma@yahoo.com	Çınarlı Mah. Erkin Sokak Derince/Kocaeli	Bireysel
5	Mustafa Şahin	05441000015	2026-03-16 13:38:57.709668	02624115555	mustafa@gmail.com	Yavuz Sultan Selim Mah. Gölcük/Kocaeli	Bireysel
6	Zeynep Aydın	05441000016	2026-03-16 13:38:57.709668	02623446666	zeynep@me.com	Serdar Mah. Başiskele/Kocaeli	Bireysel
7	Ali Öztürk	05441000017	2026-03-16 13:38:57.709668	02623777777	ali@proton.me	İstasyon Mah. Kartepe/Kocaeli	Bireysel
8	Hüseyin Yıldız	05441000018	2026-03-16 13:38:57.709668	02623228888	huseyin@icloud.com	Yenişehir Mah. İzmit/Kocaeli	Bireysel
9	Elif Arslan	05441000019	2026-03-16 13:38:57.709668	02625229999	elif@gmail.com	Güney Mah. Körfez/Kocaeli	Bireysel
10	Murat Doğan	05441000020	2026-03-16 13:38:57.709668	02624220000	murat@yandex.com	Değirmendere Yalı Mah. Gölcük/Kocaeli	Bireysel
12	Kazım KARTAL	05453333333	2026-03-30 13:26:26.215565	05453333334	Kaz@kaz.com	Karatepe mah. Kullukcu sk. Ege apt. No4 degirmen köy gölcük KOCAELİ	bireysel
13	COCUK 1	0532	2026-04-04 14:06:13.751423	0532	C1@c.com	Denizevler golcuk bolu	bireysel
14	Cocuk 2	0532	2026-04-04 14:07:32.953313	0532	C2@c.com	Deniz evler golcuk bolu2	bireysel
15	ahmet metmet 123	05555555522	2026-04-09 00:03:19.640699	02122222222	ahmet@a.com	uzun uzun kavaklar derinde kocaeli	bireysel
11	ARDA BİR1	05320000001	2026-03-20 16:04:39.106084	05320000001	ARDA@A.COM	KANAVA LOJ ERDEK BALIKESİR TRABZON	bireysel
20	b mobile muz	1111	2026-04-12 14:20:18.849488	0000	A@a.com	Mobile2	bireysel
19	b mobile nar	2222	2026-04-12 14:19:33.107749	000	E@a.com	Mobile 1	bireysel
22	b web armut 	777	2026-04-12 14:26:12.374641	8888	wa@a.com	web2	bireysel
21	b web elma	0000	2026-04-12 14:25:38.228317	0000	wel@a.com	webb1\n\n\n	bireysel
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.devices (id, customer_id, brand, model, serial_no, created_at, cihaz_turu, garanti_durumu, muster_notu, firm_id) FROM stdin;
2	1	Apple	iPad Air 5	SERI-A102	2026-03-16 13:45:12.487421	Tablet	\N	\N	\N
10	\N	Brother	HL-L2350DW	FIRM-M501	2026-03-16 13:45:12.487421	Yazıcı	\N	\N	5
12	\N	Epson	L3250 Tanklı	FIRM-P701	2026-03-16 13:45:12.487421	Yazıcı	\N	\N	7
6	\N	HP	ProBook 450	FIRM-Y101	2026-03-16 13:45:12.487421	Notebook	\N	\N	1
7	\N	Dell	Latitude 5420	FIRM-K201	2026-03-16 13:45:12.487421	Notebook	\N	\N	2
8	\N	Lenovo	ThinkPad E15	FIRM-E301	2026-03-16 13:45:12.487421	Notebook	\N	\N	3
11	\N	Apple	MacBook Pro M2	FIRM-D601	2026-03-16 13:45:12.487421	Notebook	\N	\N	6
1	1	Apple	iPhone 13	SERI-A101	2026-03-16 13:45:12.487421	Cep Telefonu	\N	\N	\N
3	2	Samsung	Galaxy S23	SERI-M201	2026-03-16 13:45:12.487421	Cep Telefonu	\N	\N	\N
5	3	Xiaomi	Redmi Note 12	SERI-AY301	2026-03-16 13:45:12.487421	Cep Telefonu	\N	\N	\N
9	\N	Zebra	TC21 El Terminali	FIRM-G401	2026-03-16 13:45:12.487421	Masaüstü Bilgisayar	\N	\N	4
4	2	Samsung	Buds 2 Pro	SERI-M202	2026-03-16 13:45:12.487421	Cep Telefonu	\N	\N	\N
13	\N	Efes	Star	001	2026-03-16 16:39:54.151998	Masaüstü Bilgisayar	Var (Resmi)	Kablo dahil geldi	11
14	\N	Apple	T10	1	2026-03-16 21:02:28.20328	Cep Telefonu	Var (Dükkan)	Micro	11
15	\N	Casped	1	1	2026-03-16 21:36:46.075314	Notebook	Var (Dükkan)	Isinma	8
16	\N	hundai	aq1	001	2026-03-17 18:24:15.181297	Masaüstü Bilgisayar	Var (Resmi)	kablolu	11
17	\N	Apple	1	1	2026-03-18 00:09:59.544321	Tablet	Var (Dükkan)	Kablo	2
18	\N	Hp	Ms1	S1	2026-03-18 13:37:36.850338	Masaüstü Bilgisayar	Var (Resmi)	Ekran karti	1
19	\N	Cas	T	5	2026-03-18 14:37:59.433952	Notebook	Var (Resmi)	Hhh	8
20	7	A	A	A	2026-03-18 16:17:04.148144	Notebook	Var (Dükkan)	A	\N
21	\N	Hp	1	1	2026-03-18 17:37:22.497354	Masaüstü Bilgisayar	Var (Dükkan)	1	9
22	9	Bzbxjx	Hzhdjd	Hxhdhxhx	2026-03-18 17:57:35.929948	Yazıcı	Var (Dükkan)	Hdhxjc	\N
23	11	Samsung1	T21	001	2026-03-20 17:15:34.210581	Cep Telefonu	Var (Resmi)	Acele	\N
24	11	Samsung2	Tt	002	2026-03-20 17:17:00.169457	Cep Telefonu	Var (Resmi)	Kasa kirik	\N
25	\N	Samsung3	Tt3	01	2026-03-20 17:18:23.072503	Cep Telefonu	Var (Resmi)	Ikinci el	12
26	11	Son	S2	222	2026-03-20 17:46:54.005075	Notebook	Var (Dükkan)	Musteri notu	\N
27	11	sony	ASA	4	2026-03-23 18:15:28.213033	Masaüstü Bilgisayar	Var (Dükkan)	HFG	\N
28	\N	DGDFG	GDFGDFG	N/A	2026-03-23 18:24:40.599405	Yazıcı	Var (Resmi)	DFGDFG	12
29	\N	Hsvdggd	Hshshdh	Hegshdh	2026-03-23 18:56:19.310521	Notebook	Var (Dükkan)	Hehedhdh	8
30	\N	Sony	Ss	A1	2026-03-24 00:31:05.926667	Tablet	Var (Resmi)	Aman ha	11
31	\N	Sun	Bun	001	2026-03-24 12:25:16.39345	Notebook	Var (Resmi)	Aman	6
32	3	Alkatel	Asl	001	2026-03-24 13:48:10.385114	Cep Telefonu	Var (Resmi)	Anten	\N
33	6	App	1	121	2026-03-24 13:56:46.96404	Tablet	Yok	Wifi	\N
34	\N	App	Hsgsgs	Bshshs	2026-03-24 18:06:47.090891	Tablet	Yok	Hshdbdndnd	10
35	6	App	01	2	2026-03-25 18:54:23.940916	Cep Telefonu	Var (Resmi)	Gaz	\N
36	12	Apple	M4	00101	2026-03-30 16:39:39.49279	Notebook	Var (Resmi)	Mavi ekran sorunu var	\N
37	12	Apple	M4	00101	2026-03-30 16:53:51.149086	Notebook	Var (Resmi)	Acele lazim	\N
38	\N	Samsu	K41	P01	2026-03-31 13:56:37.362149	Tablet	Var (Resmi)	Kablo sizde	13
39	\N	Hp	Bictus	009	2026-04-01 13:17:50.251618	Yazıcı	Var (Dükkan)	Toner verdim	12
40	\N	Ana1	Ss	01	2026-04-04 14:11:04.630735	Cep Telefonu	Var (Resmi)	Sarjli verildi	14
41	13	C1 	Ss1	001	2026-04-04 14:12:20.956368	Cep Telefonu	Var (Resmi)	Sarji yok	\N
42	\N	Traş	Canli	19	2026-04-05 12:26:15.490585	Tablet	Var (Resmi)	Kesmiyor	11
43	\N	fdfd	fgdfg	dfgdf	2026-04-09 12:31:20.536818	Notebook	Var (Dükkan)	dfgdfg	2
44	\N	yeni cihaz 	dikkat	09	2026-04-09 12:47:51.920465		Var (Dükkan)	webb 2 iş kaydı	2
45	\N	sony	t10	09	2026-04-09 12:53:31.328439	Cep Telefonu	Var (Dükkan)	webb kaydı3	15
46	12	samsung	s26	001	2026-04-10 18:18:05.309288	Cep Telefonu	Var (Dükkan)	pili sizde	\N
47	20	apple	f17	1	2026-04-12 15:08:40.008368	Cep Telefonu	Var (Resmi)	servis 1	\N
48	\N	apple	t17	2	2026-04-12 15:10:39.690827	Cep Telefonu	Var (Resmi)	servis 2	21
49	22	apple	s17	3	2026-04-12 15:14:27.976118	Cep Telefonu	Var (Dükkan)	servis 3	\N
50	\N	Apple	H17	9	2026-04-12 15:17:23.606301	Cep Telefonu	Var (Dükkan)	Servis 3	23
51	\N	hp	t10	001	2026-04-12 23:27:55.032647	Cep Telefonu	Yok	sesi bozuk deneme	2
\.


--
-- Data for Name: envanter; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.envanter (id, barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, son_guncelleme, satis_fiyati, kar_orani_ozel, kdv_orani_ozel) FROM stdin;
1	GLCK-10001	Test Type-C Şarj Kablosu	Tüm Type-C Cihazlar	Dexim	15	120.50	2026-03-21 13:37:03.914552	0.00	\N	\N
11	GLCK-276022-6118	Kopuk	Genel	Genel	1	1.00	2026-03-21 17:11:54.327991	0.00	\N	\N
13	GLCK-744376-2991	Yeni Ad degisti	Samsung Galaxy S23	Asil	1	123.00	2026-03-21 19:32:32.913569	0.00	\N	\N
15	GLCK-293761-1140	Gvvb	Samsung Galaxy S23	Son durum	4	20.00	2026-03-21 20:32:53.616149	0.00	\N	\N
16	GLCK-434594-4058	Gvvb	Samsung Galaxy S23	Son2	3	25.00	2026-03-21 20:34:18.801469	0.00	\N	\N
17	GLCK-273328-2512	san	Apple iPad Air 5		6	0.00	2026-03-21 22:33:11.195905	0.00	\N	\N
7	GLCK-888956-6112	Kasa	Asus	Asus	35	40.00	2026-04-13 14:17:24.359051	0.00	\N	\N
19	GLCK-443442-1577	Tornavida kısa 3mm	Hepsi	İzeltaş	50	675.00	2026-03-31 19:55:39.538761	0.00	\N	\N
12	GLCK-595837-6515	masa	Apple iPad Air 5	Exper	5	2500.00	2026-04-13 14:39:44.122115	0.00	\N	\N
8	GLCK-565660-5703	Cpu	1980 oncesi	Cikma	151	1000.00	2026-03-31 18:56:41.73705	0.00	\N	\N
66	GLCK-508359-9625	Terminal gözü mercek	Zebra TC21 El Terminali	Uno	2	1000.00	2026-04-06 21:36:03.750464	0.00	\N	\N
9	GLCK-484958-9000	Apple cep	14/17	Apple	93	2500.00	2026-04-02 19:50:36.213656	0.00	\N	\N
23	0123456789	Cpu	13 pro	App	7	4000.00	2026-03-22 12:16:12.413941	0.00	\N	\N
59	GLCK-367020-3220	Kalem	Hepsi	Fibo	20	15.00	2026-03-31 19:59:57.121099	0.00	\N	\N
58	GLCK-184642-4955	Kalem tras	Hepsi	Faber	4	50.00	2026-03-31 20:01:16.282624	0.00	\N	\N
61	GLCK-722490-4133	Mayonez	Casped 1	Heinz	3	255.00	2026-03-31 20:05:42.505938	0.00	\N	\N
63	GLCK-869458-5276	Mayonez	Casped 1		3	25.00	2026-03-31 20:07:55.973548	0.00	\N	\N
68	GLCK-087301-2448	Varyete	Son S2	Hakki	2	255.00	2026-04-01 12:18:25.256616	0.00	\N	\N
67	GLCK-695629-2647	Biber	Zebra TC21 El Terminali	Tuzot	15	750.00	2026-04-03 00:07:08.892724	0.00	\N	\N
4	GLCK-921359-3821	Labtop ekrani	5000 serisi	Hp	4	7500.00	2026-04-10 20:43:23.198191	0.00	\N	\N
91	GLCK-892314-3464	Hp Bictus Ekran	Hp Bictus		1	7050.00	2026-04-03 17:03:24.573454	0.00	\N	\N
70	GLCK-222920-6458	Vida	Son S2	Sap	23	57.00	2026-04-01 13:47:20.834276	0.00	\N	\N
10	GLCK-546704-7568	hardisk	tüm cihazlar	hdd	36	5500.00	2026-04-14 19:52:32.621871	1250.00	\N	\N
26	1123456799	Ekran karti1	Tv1	Sony12	9	1500.00	2026-04-11 00:42:13.71716	0.00	\N	\N
6	1231231231232	Ekran ipad	11 ler	Apple	10	12000.00	2026-04-11 00:48:36.714155	0.00	\N	\N
106	GLCK-930042-9417	Iphone ekrani 10 inch	Y17	Apple	4	3750.00	2026-04-12 17:59:49.775618	0.00	\N	\N
107	GLCK-004965-8073	Iphone ekran 8 inch	T9	Apple	3	4580.00	2026-04-12 18:00:52.368032	0.00	\N	\N
92	GLCK-394218-1642	Razor	Traş Canli	Sanyo	2	1200.00	2026-04-05 12:30:21.176538	0.00	\N	\N
93	GLCK-525443-6270	Kesme bicagi	Traş Canli	Sony	3	550.00	2026-04-05 12:32:23.916617	0.00	\N	\N
69	GLCK-505928-1928	Somun	Son S2	Aeg	18	72.00	2026-04-01 16:30:53.316257	0.00	\N	\N
108	GLCK-857008-4892	iphone ekran 6 inch	 7 serisi	apple	3	1000.00	2026-04-12 19:33:45.417653	0.00	\N	\N
94	GLCK-635690-8456	Elek	Traş Canli	Tras	2	85.00	2026-04-05 14:14:32.538429	0.00	\N	\N
90	GLCK-730692-9993	Ram	Hp Bictus	App	4	3800.00	2026-04-05 15:41:05.709365	0.00	\N	\N
110	GLCK-432694-5876	sarımsak	a serisi	hp	10	150.00	2026-04-12 23:19:07.533839	0.00	\N	\N
62	GLCK-791998-2528	Ketcap	Iphone	Pinar	4	500.00	2026-04-12 20:47:40.632664	0.00	\N	\N
99	GLCK-037474-8159	Ddr ram 1600	sony	Yeni 	4	4000.00	2026-04-06 21:32:51.982439	0.00	\N	\N
\.


--
-- Data for Name: firms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.firms (id, firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres, created_at) FROM stdin;
1	Yıldıran Yazılım Ltd. Şti.	Kemal Yıldıran	05321000001	02621002030	1234567890	info@yildiran.com	Gölcük, Kocaeli	2026-03-16 13:42:30.499229
2	Kalandar Teknoloji	Murat Kalandar	05321000002	02622003040	0987654321	destek@kalandar.com	İzmit, Kocaeli	2026-03-16 13:42:30.499229
3	Eren İnşaat ve Mimarlık	Selim Eren	05321000003	02623004050	1122334455	muhasebe@eren.com	Başiskele, Kocaeli	2026-03-16 13:42:30.499229
4	Gölcük Otomotiv Servis	Hasan Usta	05321000004	02624005060	5544332211	servis@golcuk.com	Sanayi Sitesi, Gölcük	2026-03-16 13:42:30.499229
5	Mavi Lojistik Hizmetleri	Caner Mavi	05321000005	02625006070	6677889900	operasyon@mavi.com	Körfez, Kocaeli	2026-03-16 13:42:30.499229
7	Poyraz Enerji Sistemleri	Ayşe Poyraz	05321000007	02627008090	4455667788	admin@poyraz.com	Kartepe, Kocaeli	2026-03-16 13:42:30.499229
9	Odak Reklam Ajansı	Selin Odak	05321000009	02629001020	7788990011	tasarim@odak.com	Çarşı, İzmit	2026-03-16 13:42:30.499229
10	Vatan Tekstil Fabrikası	İbrahim Vatan	05321000010	02620002030	3344556677	uretim@vatan.com	Dilovası, Kocaeli	2026-03-16 13:42:30.499229
6	Derin Denizcilik A.Ş.	Kaptan Yavuz	05321000006	\N	9988776655	kaptan@derin.com	Marina, Kocaeli	2026-03-16 13:42:30.499229
11	Kamil holding	AHMET KAMIL	0532	0532	222	g@g.com	Karayollari	2026-03-16 16:39:00.956743
12	ARDA İKİ	ARDA DARDA	05320000002	05320000002	001	ARDA2@A.COM	ELMALI MAH EŞME TRABZON	2026-03-20 16:06:12.41277
13	Kara Kazım A.Ş.	Kazım KARTAL	05335555555	05335555556	123456	KK@a.Com	Düvenli mah. dereli sk. inci apt. no 26 ciflik köy sultanhisar gebze KOCAELİ	2026-03-30 16:14:46.651765
15	Baba	Babi	0532	0532	0002	b1@b.com	Deniz evler baba golcuk bolu	2026-04-04 14:09:45.637404
17	komodor yazılım a.ş.	kemal kükrer	05324445566	\N	\N	komo@k.com	halıdere uzunköy lisesi yanı şalpazarı adana	2026-04-09 00:26:03.043206
18	eken holding	kamşı bey	09998887766	\N	1234567891011	ka@xn--tea.com	gaziler sokak tarbazon 	2026-04-09 00:29:19.467171
8	Zirve Gıda Sanayi	Mert Zirve	05321000008	02628009010	2233445566	satis@zirve.com	Kullar,  GÖLCÜK Kocaeli	2026-03-16 13:42:30.499229
14	Ana1	Anne	0532	0532	001	a1@a.com	Denizevler ana golcuk baba	2026-04-04 14:08:41.831709
21	f mobile muz	Muzmuz	3333	888	0100000000000	muzmuzmuz@muz.com	Mobile3	2026-04-12 14:21:30.565524
22	f Mobile nar	Narinar	4444	6666	088	nar@a.com	Mobile4	2026-04-12 14:22:16.191565
23	f web armut	muzmuz 	029202	2222	0000	mw@a.com	web3	2026-04-12 14:34:33.682745
24	f web elma 	naranar	77777	\N	717171	nw@a.com	WEB4	2026-04-12 14:35:47.213373
\.


--
-- Data for Name: kasa_islemleri; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kasa_islemleri (id, islem_yonu, kategori, tutar, aciklama, baglanti_id, islem_tarihi, islem_yapan, servis_no) FROM stdin;
1	GİRİŞ	Sistem Açılışı	1000.00	Dükkan kasasına açılış sermayesi konuldu.	\N	2026-03-22 14:17:15.633079	Sistem Admin	\N
2	GİRİŞ	Tamir Geliri	1000.00	Otomatik Tahsilat: Cihaz detaylı ekrandan teslim edildi.	71	2026-03-22 15:40:11.957419	Sistem Otomasyonu	26032006
3	GİRİŞ	Randevu Tahsilatı	2500.00	Usta: Usta 1 | Tahsilat Notu: Takip	\N	2026-03-22 17:44:41.432561	Banko Onay	26032007
4	GİRİŞ	Randevu Tahsilatı	9999.00	Usta: Usta 1 | Tahsilat Notu: Dokuz	\N	2026-03-22 17:46:57.150232	Banko Onay	26032005
5	GİRİŞ	Randevu Tahsilatı	9000.00	Usta: Usta 1 | Tahsilat Notu: Yes	\N	2026-03-22 17:47:57.563371	Banko Onay	26032004
6	GİRİŞ	Stok Satışı	0.00	Stok Satışı: Hardisk (1 Adet)	10	2026-03-22 18:11:26.876995	Barkod Satış	\N
7	GİRİŞ	Stok Satışı	0.00	Stok Satışı: Hardisk (1 Adet)	10	2026-03-22 18:15:11.823902	Barkod Satış	\N
8	GİRİŞ	Stok Satışı	1250.00	Stok Satışı: Hardisk (1 Adet)	10	2026-03-22 18:18:29.098867	Barkod Satış	\N
9	GİRİŞ	Stok Satışı	360.00	Stok Satışı: Hardisk | Kar: %20 | KDV: %20 | Net Kar: 50.00 TL	10	2026-03-22 18:38:11.889411	Akıllı Sistem	\N
10	GİRİŞ	Stok Satışı	0.00	Stok Satışı: Hardisk | Kar: %20 | KDV: %20 | Net Kar: 0.00 TL	10	2026-03-22 18:52:41.575553	Akıllı Sistem	\N
11	GİRİŞ	Stok Satışı	360.00	Stok Satışı: Hardisk | Kar: %20 | KDV: %20 | Net Kar: 50.00 TL	10	2026-03-22 18:54:06.540924	Akıllı Sistem	\N
12	GİRİŞ	Stok Satışı	720.00	Stok Satışı: Hardisk | Kar: %20 | KDV: %20 | Net Kar: 100.00 TL	10	2026-03-22 18:54:52.357421	Akıllı Sistem	\N
13	GİRİŞ	Stok Satışı	345.00	Stok Satışı: Hardisk (%5 Akraba İndirimi) | Kar: %15 | KDV: %20 | Net Kar: 37.50 TL	10	2026-03-22 19:01:10.24725	Akıllı Sistem	\N
14	GİRİŞ	Stok Satışı	345.00	Stok Satışı: Hardisk (%5 Akraba İndirimi) | Kar: %15 | KDV: %20 | Net Kar: 37.50 TL	10	2026-03-22 19:19:10.038365	Akıllı Sistem	\N
15	GİRİŞ	Stok Satışı	345.00	Stok Satışı: Hardisk (%5 Akraba İndirimi) | Kar: %15 | KDV: %20 | Net Kar: 37.50 TL	10	2026-03-22 19:19:50.451423	Akıllı Sistem	\N
16	GİRİŞ	Stok Satışı	210.00	Stok Satışı: Hardisk (Özel İskonto: %50) | Kar: %-30 | Tahsilat: 210.00	\N	2026-03-22 19:24:09.850541	Barkod Satış	\N
17	GİRİŞ	Stok Satışı	360.00	Stok Satışı: Hardisk | Alış: 250 | Satış: 360.00	\N	2026-03-22 19:44:35.171472	Barkod Satış	\N
18	GİRİŞ	Stok Satışı	360.00	Stok Satışı: Hardisk | Alış: 250 | Satış: 360.00	\N	2026-03-22 19:45:08.310896	Barkod Satış	\N
19	GİRİŞ	Stok Satışı	330.00	Stok Satışı: Hardisk (%10 İskonto) | Alış: 250 | Satış: 330.00	\N	2026-03-22 19:46:47.702141	Barkod Satış	\N
20	GİRİŞ	Stok Satışı	300.00	Stok Satışı: Hardisk (%20 İskonto) | Alış: 250 | Satış: 300.00	\N	2026-03-22 19:47:02.049844	Barkod Satış	\N
21	GİRİŞ	Stok Satışı	336.00	Stok Satışı: Hardisk (%50 İskonto) | Alış: 400 | Satış: 336.00	\N	2026-03-22 19:55:48.043633	Barkod Satış	\N
22	GİRİŞ	Stok Satışı	576.00	Stok Satışı: Hardisk | Alış: 400 | Satış: 576.00	\N	2026-03-22 20:05:20.140398	Barkod Satış	\N
23	GİRİŞ	Randevu Tahsilatı	5000.00	Usta: Usta 1 | Tahsilat Notu: Not yok	\N	2026-03-22 22:12:35.924711	Banko Onay	26031920
24	GİRİŞ	Randevu Tahsilatı	2500.00	Usta: Usta 1 | Tahsilat Notu: Tamam	\N	2026-03-22 22:12:49.485883	Banko Onay	26031919
25	GİRİŞ	Tamir Geliri	10000.00	Otomatik Tahsilat: Cihaz detaylı ekrandan teslim edildi.	74	2026-03-22 22:35:32.229585	Sistem Otomasyonu	26032204
26	GİRİŞ	Randevu Tahsilatı	40000.00	Usta: Usta 1 | Tahsilat Notu: Hayda	\N	2026-03-22 22:39:26.821439	Banko Onay	26032203
27	GİRİŞ	Kasaya Nakit Girişi	10000.00	Sermaye aktarimi	\N	2026-03-23 12:47:43.877725	Admin	\N
28	GİRİŞ	Kasaya Nakit Girişi	1000.00	Guzel	\N	2026-03-23 12:48:17.554661	Admin	\N
29	GİRİŞ	Kasaya Nakit Girişi	1000.00	Es	\N	2026-03-23 12:53:47.152509	Admin	\N
30	GİRİŞ	Tamir Ücreti Tahsili	3000.00	26032302 nolu servis tahsilatı.	76	2026-03-23 14:43:34.8744	Banko	26032302
31	GİRİŞ	Tamir Ücreti Tahsili	7500.00	26032202 nolu servis tahsilatı.	73	2026-03-23 14:44:26.183022	Banko	26032202
32	GİRİŞ	Kasaya Nakit Girişi	500.00	Is	\N	2026-03-23 15:08:01.483689	Admin	\N
33	GİRİŞ	Kasaya Nakit Girişi	501.00	Vvh	\N	2026-03-23 15:08:32.461573	Admin	\N
34	GİRİŞ	Kasaya Nakit Girişi	502.00	Fgh	\N	2026-03-23 15:11:38.113443	Admin	\N
35	GİRİŞ	Kasaya Nakit Girişi	1500.00	Vsgsgs	\N	2026-03-23 15:19:30.510553	Admin	\N
36	GİRİŞ	Kasaya Nakit Girişi	1501.00	Gsgsgs	\N	2026-03-23 15:20:14.351229	Admin	\N
37	GİRİŞ	Kasaya Nakit Girişi	1502.00	Ksjd	\N	2026-03-23 15:21:26.161151	Admin	\N
38	GİRİŞ	Kasaya Nakit Girişi	2000.00	Ttt	\N	2026-03-23 15:22:29.183725	Admin	\N
39	GİRİŞ	Kasaya Nakit Girişi	508.00	Bvbn\n	\N	2026-03-23 15:26:24.582133	Admin	\N
40	GİRİŞ	Kasaya Nakit Girişi	1500.00	Gsvsv\n	\N	2026-03-23 15:35:15.131253	Admin	\N
41	GİRİŞ	Kasaya Nakit Girişi	1.00	Bebdb\n	\N	2026-03-23 15:35:42.845263	Admin	\N
42	GİRİŞ	Kasaya Nakit Girişi	900.00	Gghhgv	\N	2026-03-23 16:00:49.914085	Admin	\N
43	GİRİŞ	Tamir Ücreti Tahsili	3518.00	26032305 nolu servis tahsilatı.	79	2026-03-23 16:09:18.222476	Banko	26032305
44	GİRİŞ	Tamir Ücreti Tahsili	75.00	26032306 nolu servis tahsilatı.	80	2026-03-23 16:13:36.977968	Banko	26032306
45	GİRİŞ	Tamir Ücreti Tahsili	2.00	26032307 nolu servis tahsilatı.	81	2026-03-23 17:17:56.158809	Banko	26032307
46	GİRİŞ	Kasaya Nakit Girişi	1500.00	Gwgwg	\N	2026-03-24 00:08:14.305901	Admin	\N
47	GİRİŞ	Tamir Ücreti Tahsili	15000.00	26032312 nolu servis tahsilatı.	86	2026-03-24 00:16:19.522179	Banko	26032312
48	GİRİŞ	Kasaya Nakit Girişi	2.00	Vsgs	\N	2026-03-24 12:09:35.20647	Admin	\N
49	GİRİŞ	Tamir Ücreti Tahsili	7502.00	26032310 nolu servis tahsilatı.	84	2026-03-24 12:18:19.836109	Banko	26032310
50	GİRİŞ	Tamir Ücreti Tahsili	6757.00	26032402 nolu cihaz tamir bedeli tahsilatı.	89	2026-03-24 13:45:46.541196	Banko	26032402
53	GİRİŞ	Tamir Ücreti Tahsili	752.00	26032404 nolu cihaz tamir bedeli tahsilatı.	91	2026-03-24 14:00:15.07362	Banko	26032404
54	GİRİŞ	Tamir Ücreti Tahsili	17.00	26032405 nolu cihaz tamir bedeli tahsilatı.	92	2026-03-24 14:02:11.82952	Banko	26032405
55	GİRİŞ	Tamir Ücreti Tahsili	0.00	26032407 nolu cihaz tamir bedeli tahsilatı.	94	2026-03-24 14:10:55.168357	Banko	26032407
57	GİRİŞ	Tamir Ücreti Tahsili	752.00	26032414 nolu servis tahsilatı.	101	2026-03-24 14:37:30.439148	Banko	26032414
58	GİRİŞ	Tamir Ücreti Tahsili	0.00	26032415 nolu cihaz tamir bedeli tahsilatı.	102	2026-03-24 14:41:13.801128	Banko	26032415
59	GİRİŞ	Tamir Ücreti Tahsili	3764.00	26032418 nolu servis tahsilatı.	105	2026-03-24 18:09:15.068765	Banko	26032418
60	GİRİŞ	Kasaya Nakit Girişi	505.00	Jcjvuvuv	\N	2026-03-24 18:09:58.126508	Admin	\N
61	GİRİŞ	Kasaya Nakit Girişi	606060.00	Ycycycyc	\N	2026-03-24 18:10:33.048124	Admin	\N
62	GİRİŞ	Kasaya Nakit Girişi	52.00	Jviv	\N	2026-03-24 18:11:23.856347	Admin	\N
63	GİRİŞ	Tamir Ücreti Tahsili	1050.00	26032419 nolu servis tahsilatı.	106	2026-03-24 18:21:38.297946	Banko	26032419
64	GİRİŞ	Kasaya Nakit Girişi	230.00	Hshsh	\N	2026-03-24 18:51:27.683288	Admin	\N
65	GİRİŞ	Tamir Ücreti Tahsili	158.00	26032420 nolu servis tahsilatı.	107	2026-03-24 18:52:04.41597	Banko	26032420
66	GİRİŞ	Randevu Tahsilatı	1001.00	Usta: Usta 1 | Tahsilat Notu: gece	\N	2026-03-24 19:11:40.924031	Banko Onay	26032316
67	GİRİŞ	Randevu Tahsilatı	1010.00	Usta: Usta 1 | Tahsilat Notu: ddc	\N	2026-03-24 20:50:37.13647	Banko Onay	26032421
68	GİRİŞ	Randevu Tahsilatı	1005.00	Usta: Usta 1 | Tahsilat Notu: sıuwhdıu	\N	2026-03-24 20:50:52.398218	Banko Onay	26032315
69	GİRİŞ	Randevu Tahsilatı	8050.00	Usta: Usta 1 | Tahsilat Notu: Gggg	\N	2026-03-24 20:50:58.168857	Banko Onay	26032314
70	GİRİŞ	Tamir Ücreti Tahsili	2262.00	26032426 nolu servis tahsilatı.	109	2026-03-24 21:46:32.416027	Banko	26032426
71	GİRİŞ	Randevu Tahsilatı	833838.00	Usta: Usta 1 | Tahsilat Notu: Uvubuv	\N	2026-03-24 22:00:29.922542	Banko Onay	26032428
72	GİRİŞ	Randevu Tahsilatı	60686.00	Usta: Usta 1 | Tahsilat Notu: Ychc	\N	2026-03-24 22:00:33.655269	Banko Onay	26032427
73	GİRİŞ	Randevu Tahsilatı	5558.00	Usta: Usta 1 | Tahsilat Notu: Ghhh	\N	2026-03-24 22:00:35.923911	Banko Onay	26032424
74	GİRİŞ	Randevu Tahsilatı	1500.00	Usta: Usta 1 | Tahsilat Notu: Gghj	\N	2026-03-24 22:00:38.566504	Banko Onay	26032423
75	GİRİŞ	Randevu Tahsilatı	1500.00	Usta: Usta 1 | Tahsilat Notu: Gghj	\N	2026-03-24 22:00:41.157476	Banko Onay	26032423
76	GİRİŞ	Randevu Tahsilatı	1111.00	Usta: Usta 1 | Tahsilat Notu: vvdv	\N	2026-03-24 22:00:44.286353	Banko Onay	26032422
77	GİRİŞ	Randevu Tahsilatı	12.00	Usta: Usta 1 | Tahsilat Notu: Cc	\N	2026-03-25 00:48:21.420572	Banko Onay	26032434
78	GİRİŞ	Randevu Tahsilatı	4545.00	Usta: Usta 1 | Tahsilat Notu: Vyvuc	\N	2026-03-25 11:45:05.925069	Banko Onay	26032429
79	GİRİŞ	Randevu Tahsilatı	505.00	Usta: Usta 1 | Tahsilat Notu: Gg	\N	2026-03-25 11:45:55.652811	Banko Onay	26032430
80	GİRİŞ	Randevu Tahsilatı	1900.00	Usta: Usta 1 | Tahsilat Notu: ddddcc	\N	2026-03-25 11:46:00.753727	Banko Onay	26032431
81	GİRİŞ	Randevu Tahsilatı	1.00	Usta: Usta 1 | Tahsilat Notu: Rr	\N	2026-03-25 11:46:05.084558	Banko Onay	26032432
82	GİRİŞ	Randevu Tahsilatı	1009.00	Usta: Usta 1 | Tahsilat Notu: Ggv	\N	2026-03-25 11:46:09.821695	Banko Onay	26032433
83	GİRİŞ	Randevu Tahsilatı	223.00	Usta: Usta 1 | Tahsilat Notu: we	\N	2026-03-25 11:46:14.286082	Banko Onay	26032501
84	GİRİŞ	Randevu Tahsilatı	1000.00	Usta: Usta 1 | Tahsilat Notu: usta derki	\N	2026-03-25 11:46:17.896792	Banko Onay	26032502
85	GİRİŞ	Randevu Tahsilatı	1000.00	Usta: Usta 1 | Tahsilat Notu: qqq	\N	2026-03-25 11:46:21.505116	Banko Onay	26032503
86	GİRİŞ	Randevu Tahsilatı	555.00	Usta: Usta 1 | Tahsilat Notu: Ggg	\N	2026-03-25 11:46:24.973936	Banko Onay	26032504
87	GİRİŞ	Randevu Tahsilatı	8000.00	Usta: Usta 1 | Tahsilat Notu: Yg	\N	2026-03-25 11:46:28.607551	Banko Onay	26032505
88	GİRİŞ	Randevu Geliri Tahsili	2222.00	26032510 nolu randevu tahsilatı.	79	2026-03-25 15:22:53.032097	Banko	26032510
89	GİRİŞ	Randevu Geliri Tahsili	2222.00	26032510 nolu randevu tahsilatı.	79	2026-03-25 15:23:33.987962	Banko	26032510
90	GİRİŞ	Randevu Geliri Tahsili	2222.00	26032510 nolu randevu tahsilatı.	79	2026-03-25 15:39:18.450664	Banko	26032510
91	GİRİŞ	Randevu Geliri Tahsili	2222.00	26032510 nolu randevu tahsilatı.	79	2026-03-25 15:55:18.235076	Banko	26032510
92	GİRİŞ	Randevu Geliri Tahsili	1001.00	26032509 nolu randevu tahsilatı.	78	2026-03-25 15:55:52.274112	Banko	26032509
93	GİRİŞ	Randevu Geliri Tahsili	1001.00	26032508 nolu randevu tahsilatı.	77	2026-03-25 15:56:02.047172	Banko	26032508
94	GİRİŞ	Randevu Geliri Tahsili	1555.00	26032506 nolu randevu tahsilatı.	76	2026-03-25 15:56:25.290784	Banko	26032506
95	GİRİŞ	Tamir Ücreti Tahsili	222.00	26032507 nolu randevu tahsilatı.	110	2026-03-25 18:44:29.885111	Banko	26032507
96	GİRİŞ	Randevu Geliri Tahsili	1500.00	26032514 nolu randevu tahsilatı.	82	2026-03-25 18:51:34.038894	Banko	26032514
97	GİRİŞ	Tamir Ücreti Tahsili	255.00	26032513 nolu randevu tahsilatı.	111	2026-03-25 18:52:27.909232	Banko	26032513
98	GİRİŞ	Tamir Ücreti Tahsili	250.00	26032425 nolu randevu tahsilatı.	108	2026-03-25 18:53:38.405458	Banko	26032425
99	GİRİŞ	Randevu Geliri Tahsili	14987.00	26032512 nolu randevu tahsilatı.	81	2026-03-25 23:02:58.303687	Banko	26032512
100	GİRİŞ	Randevu Geliri Tahsili	1499.00	26032511 nolu randevu tahsilatı.	80	2026-03-25 23:03:03.855427	Banko	26032511
101	GİRİŞ	Tamir Ücreti Tahsili	550.00	26032515 nolu randevu tahsilatı.	112	2026-03-25 23:03:18.988105	Banko	26032515
102	GİRİŞ	Randevu Geliri Tahsili	8.00	26032519 nolu randevu tahsilatı.	84	2026-03-26 09:51:13.822153	Banko	26032519
103	GİRİŞ	Kasaya Nakit Girişi	9.00	U	\N	2026-03-26 10:13:03.461289	Admin	\N
104	GİRİŞ	Tamir Ücreti Tahsili	833.00	26032516 nolu cihaz tamir bedeli tahsilatı.	113	2026-03-26 10:15:06.954066	Banko	26032516
105	GİRİŞ	Tamir Ücreti Tahsili	101.00	26032518 nolu randevu tahsilatı.	114	2026-03-26 10:15:41.829947	Banko	26032518
106	GİRİŞ	Randevu Tahsilatı	10.00	Usta: Usta 1 | Tahsilat Notu: g	\N	2026-03-26 13:14:08.639528	Banko Onay	26032517
107	GİRİŞ	Kasaya Nakit Girişi	500.00	Gg	\N	2026-03-26 13:14:41.869526	Admin	\N
108	GİRİŞ	Randevu Tahsilatı	101.00	Usta: Usta 1 | Tahsilat Notu: Vgh	\N	2026-03-26 13:19:06.60178	Banko Onay	26032601
109	GİRİŞ	Randevu Tahsilatı	669.00	Usta: Usta 1 | Tahsilat Notu: Tt	\N	2026-03-26 13:19:16.222027	Banko Onay	26032602
110	GİRİŞ	Randevu Tahsilatı	2.00	Usta: Usta 1 | Tahsilat Notu: Not yok	\N	2026-03-26 13:19:19.446018	Banko Onay	26032603
111	GİRİŞ	Randevu Tahsilatı	94989.00	Usta: Usta 1 | Tahsilat Notu: Jsjd\n	\N	2026-03-26 13:25:47.912678	Banko Onay	26032605
112	GİRİŞ	Randevu Tahsilatı	15.00	Usta: Usta 1 | Tahsilat Notu: Not yok	\N	2026-03-26 13:28:34.79222	Banko Onay	26032606
113	GİRİŞ	Tamir Ücreti Tahsili	152.00	26032604 nolu servis tahsilatı.	115	2026-03-26 13:29:31.130054	Banko	26032604
114	GİRİŞ	Tamir Ücreti Tahsili	2025.00	26032607 nolu cihaz tamir bedeli tahsilatı.	116	2026-03-26 13:35:20.958675	Banko	26032607
115	GİRİŞ	Randevu Tahsilatı	10.00	Usta: Usta 1 | Tahsilat Notu: Not yok	\N	2026-03-26 13:39:22.373877	Banko Onay	26032608
116	GİRİŞ	Kasaya Nakit Girişi	250.00	Bghy	\N	2026-03-26 13:40:08.071856	Admin	\N
117	GİRİŞ	Randevu Tahsilatı	444.00	Usta: Usta 1 | Tahsilat Notu: G	\N	2026-03-26 14:22:20.571063	Banko Onay	26032611
118	GİRİŞ	Randevu Geliri Tahsili	1128.00	26032612 nolu servis tahsilatı.	94	2026-03-26 15:48:21.318219	Banko	26032612
119	GİRİŞ	Randevu Geliri Tahsili	1128.00	26032612 nolu servis tahsilatı.	94	2026-03-26 16:24:54.418983	Banko	26032612
120	GİRİŞ	Randevu Geliri Tahsili	1137.00	26032619 nolu servis tahsilatı.	99	2026-03-26 17:32:07.131985	Banko	26032619
121	GİRİŞ	Randevu Geliri Tahsili	12500.00	26032621 nolu servis tahsilatı.	101	2026-03-26 18:35:17.982836	Banko	26032621
122	GİRİŞ	Randevu Geliri Tahsili	1250.00	26032621 nolu servis tahsilatı.	101	2026-03-26 18:51:49.624745	Banko	26032621
123	GİRİŞ	Randevu Geliri Tahsili	14547.00	26032622 nolu servis tahsilatı.	102	2026-03-26 18:58:03.841792	Banko	26032622
240	ÇIKIŞ	Diğer Giderler	1500.00	Avans 2	\N	2026-04-03 00:07:54.926953	Sistem	\N
124	GİRİŞ	Randevu Geliri Tahsili	14547.00	26032622 nolu servis tahsilatı.	102	2026-03-26 19:03:41.503811	Banko	26032622
125	GİRİŞ	Randevu Geliri Tahsili	14547.00	26032622 nolu servis tahsilatı.	102	2026-03-26 19:04:08.466206	Banko	26032622
126	GİRİŞ	Randevu Geliri Tahsili	14547.00	26032622 nolu servis tahsilatı.	102	2026-03-26 19:21:11.254683	Banko	26032622
127	GİRİŞ	Randevu Geliri Tahsili	1250.00	26032621 nolu servis tahsilatı.	101	2026-03-26 19:23:02.594226	Banko	26032621
128	GİRİŞ	Randevu Geliri Tahsili	1251.00	26032623 nolu servis tahsilatı.	103	2026-03-26 19:35:02.459966	Banko	26032623
129	GİRİŞ	Randevu Geliri Tahsili	300.00	26032624 nolu servis tahsilatı.	104	2026-03-26 20:26:42.917118	Banko	26032624
130	GİRİŞ	Randevu Geliri Tahsili	21294.00	26032625 nolu servis tahsilatı.	105	2026-03-26 23:56:34.949518	Banko	26032625
131	GİRİŞ	Randevu Geliri Tahsili	14196.00	26032625 nolu işlem tahsilatı.	105	2026-03-27 00:09:48.071804	Banko	26032625
132	GİRİŞ	Randevu Geliri Tahsili	900.00	26032620 nolu işlem tahsilatı.	100	2026-03-27 00:14:52.716203	Banko	26032620
133	GİRİŞ	Randevu Geliri Tahsili	606.00	26032701 nolu işlem tahsilatı.	106	2026-03-27 00:40:02.090109	Banko	26032701
134	GİRİŞ	Tamir Ücreti Tahsili	4125.00	26033001 nolu işlem tahsilatı.	119	2026-03-30 18:09:10.894075	Banko	26033001
135	GİRİŞ	Randevu Geliri Tahsili	2355.00	26033002 nolu işlem tahsilatı.	108	2026-03-30 19:13:31.684961	Banko	26033002
136	GİRİŞ	Stok Satışı	576.00	Stok Satışı: Hardisk | Alış: 400 | Satış: 576.00	\N	2026-03-30 20:12:23.806518	Barkod Satış	\N
137	GİRİŞ	Stok Satışı	6912.00	Stok Satışı: Apple cep | Alış: 4800 | Satış: 6912.00	\N	2026-03-30 20:21:38.18685	Barkod Satış	\N
138	GİRİŞ	Stok Satışı	6912.00	Stok Satışı: Apple cep | Alış: 4800 | Satış: 6912.00	\N	2026-03-30 20:24:31.100962	Barkod Satış	\N
139	GİRİŞ	Kasaya Nakit Girişi	555.00	Ff	\N	2026-03-30 20:26:08.778111	Admin	\N
140	GİRİŞ	Stok Satışı	576.00	Stok Satışı: Hardisk | Alış: 400 | Satış: 576.00	\N	2026-03-31 09:38:35.483799	Barkod Satış	\N
141	GİRİŞ	Stok Satışı	1250.00	Stok Satışı: Hardisk | Alış: 0 | Satış: 1250.00	\N	2026-03-31 10:09:13.66115	Barkod Satış	\N
142	GİRİŞ	Stok Satışı	0.00	Stok Satışı: Apple cep | Alış: 0 | Satış: 0.00	\N	2026-03-31 11:09:03.571334	Barkod Satış	\N
143	GİRİŞ	Stok Satışı	0.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 0 ₺	\N	2026-03-31 12:27:09.706653	Barkod Satış	\N
144	GİRİŞ	Stok Satışı	3600.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 3600 ₺	\N	2026-03-31 12:27:46.724583	Barkod Satış	\N
145	GİRİŞ	Stok Satışı	3600.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 3600 ₺	\N	2026-03-31 12:33:07.898842	Barkod Satış	\N
146	GİRİŞ	Stok Satışı	3600.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 3600 ₺	\N	2026-03-31 12:42:34.809992	Barkod Satış	\N
147	GİRİŞ	Stok Satışı	3600.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 3600 ₺	\N	2026-03-31 12:57:13.873873	Barkod Satış	\N
148	GİRİŞ	Stok Satışı	1080.00	Stok Satışı: Cpu | Adet: 1 | Birim: 1080 ₺	\N	2026-03-31 13:03:18.316634	Barkod Satış	\N
149	GİRİŞ	Stok Satışı	1080.00	Stok Satışı: Cpu | Adet: 1 | Birim: 1080 ₺	\N	2026-03-31 13:42:36.484505	Barkod Satış	\N
150	GİRİŞ	Stok Satışı	56.00	Stok Satışı: Hardisk | Adet: 1 | Birim: 56 ₺	\N	2026-03-31 13:46:09.180209	Barkod Satış	\N
151	GİRİŞ	Kasaya Nakit Girişi	2200.00	Gsgs	\N	2026-03-31 13:52:42.200251	Admin	\N
152	GİRİŞ	Tamir Ücreti Tahsili	2250.00	26032616 nolu işlem tahsilatı.	118	2026-03-31 13:53:24.27729	Banko	26032616
153	GİRİŞ	Tamir Ücreti Tahsili	4125.00	26032615 nolu işlem tahsilatı.	117	2026-03-31 13:55:17.139185	Banko	26032615
154	GİRİŞ	Tamir Ücreti Tahsili	17250.00	26033101 nolu işlem tahsilatı.	120	2026-03-31 13:59:14.096157	Banko	26033101
155	GİRİŞ	Randevu Geliri Tahsili	9999.00	26032801 nolu işlem tahsilatı.	107	2026-03-31 14:06:42.732283	Banko	26032801
156	GİRİŞ	Randevu Geliri Tahsili	16500.00	26033102 nolu işlem tahsilatı.	109	2026-03-31 14:10:21.173065	Banko	26033102
157	GİRİŞ	Tamir Ücreti Tahsili	16500.00	26033103 nolu işlem tahsilatı.	121	2026-03-31 14:16:57.804728	Banko	26033103
158	GİRİŞ	Randevu Geliri Tahsili	33000.00	26033104 nolu işlem tahsilatı.	110	2026-03-31 14:18:04.307827	Banko	26033104
159	GİRİŞ	Kasaya Nakit Girişi	2000.00	Hehe	\N	2026-03-31 14:18:25.905397	Admin	\N
160	GİRİŞ	Tamir Ücreti Tahsili	3750.00	26033105 nolu işlem tahsilatı.	122	2026-03-31 14:23:33.824196	Banko	26033105
161	GİRİŞ	Randevu Geliri Tahsili	13125.00	26033106 nolu işlem tahsilatı.	111	2026-03-31 14:37:17.131479	Banko	26033106
162	GİRİŞ	Tamir Ücreti Tahsili	11250.00	26033107 nolu işlem tahsilatı.	123	2026-03-31 14:38:07.128692	Banko	26033107
163	GİRİŞ	Kasaya Nakit Girişi	5555.00	Hhg	\N	2026-03-31 14:38:27.974293	Admin	\N
164	GİRİŞ	Stok Satışı	1224.00	Stok Satışı: Cpu | Adet: 1 | Birim: 1224 ₺	\N	2026-03-31 18:11:18.738141	Barkod Satış	\N
165	GİRİŞ	Stok Satışı	1224.00	Stok Satışı: Cpu | Adet: 1 | Birim: 1224 ₺	\N	2026-03-31 18:17:55.915787	Barkod Satış	\N
166	GİRİŞ	Stok Satışı	1122.00	Stok Satışı: Cpu (%50 İskonto) | Adet: 1 | Birim: 1122 ₺	\N	2026-03-31 18:18:33.088487	Barkod Satış	\N
167	ÇIKIŞ	Hızlı Barkod Alımı	850.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 850.00 ₺	\N	2026-03-31 18:21:01.347604	Barkod İşlem	\N
168	ÇIKIŞ	Hızlı Barkod Alımı	850.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 850.00 ₺	\N	2026-03-31 18:28:24.174538	Barkod İşlem	\N
169	ÇIKIŞ	Hızlı Barkod Alımı	850.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 850.00 ₺	\N	2026-03-31 18:29:45.718394	Barkod İşlem	\N
170	ÇIKIŞ	Hızlı Barkod Alımı	4500.00	Hızlı Stok Alımı: Hardisk | Adet: 1 | Birim: 4500.00 ₺	\N	2026-03-31 18:32:33.599739	Barkod İşlem	\N
171	ÇIKIŞ	Hızlı Barkod Alımı	850.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 850.00 ₺	\N	2026-03-31 18:49:50.652285	Barkod İşlem	\N
172	ÇIKIŞ	Hızlı Barkod Alımı	850.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 850.00 ₺	\N	2026-03-31 18:55:36.201477	Barkod İşlem	\N
173	ÇIKIŞ	Hızlı Barkod Alımı	1000.00	Hızlı Stok Alımı: Cpu | Adet: 1 | Birim: 1000.00 ₺	\N	2026-03-31 18:56:41.73705	Barkod İşlem	\N
174	ÇIKIŞ	Hızlı Barkod Alımı	4500.00	Hızlı Stok Alımı: Hardisk | Adet: 1 | Birim: 4500.00 ₺	\N	2026-03-31 18:59:54.56987	Barkod İşlem	\N
175	GİRİŞ	Stok Satışı	1320.00	Stok Satışı: Cpu (%50 İskonto) | Adet: 1 | Birim: 1320 ₺	\N	2026-03-31 19:00:53.675815	Barkod Satış	\N
176	GİRİŞ	Stok Satışı	1350.00	Stok Satışı: Cpu (%50 İskonto) | Adet: 1 | Birim: 1350 ₺	\N	2026-03-31 19:15:05.88646	Barkod Satış	\N
177	ÇIKIŞ	Hızlı Barkod Alımı	1000.00	Hızlı Stok Alımı: masa | Adet: 1 | Birim: 1000.00 ₺	\N	2026-03-31 19:44:37.174954	Barkod İşlem	\N
178	GİRİŞ	Stok Satışı	825.00	Stok Satışı: Tornavida kısa 3mm | Adet: 1 | Birim: 825 ₺	\N	2026-03-31 19:51:36.461571	Barkod Satış	\N
179	ÇIKIŞ	Hızlı Barkod Alımı	550.00	Hızlı Stok Alımı: Tornavida kısa 3mm | Adet: 1 | Birim: 550.00 ₺	\N	2026-03-31 19:53:08.556126	Barkod İşlem	\N
180	GİRİŞ	Stok Satışı	75.00	Stok Satışı: Kalem tras | Adet: 1 | Birim: 75 ₺	\N	2026-03-31 19:57:38.203552	Barkod Satış	\N
181	GİRİŞ	Tamir Ücreti Tahsili	18750.00	26033108 nolu işlem tahsilatı.	124	2026-04-01 11:09:15.079068	Banko	26033108
182	GİRİŞ	Tamir Ücreti Tahsili	14999.00	26040101 nolu işlem tahsilatı.	125	2026-04-01 12:14:02.686619	Banko	26040101
183	ÇIKIŞ	Mal Alımı	570.00	Usta Siparişi Alımı: Vida | Adet: 10 | Birim: 57 ₺	\N	2026-04-01 13:10:51.806416	Banko Stok Girişi	\N
184	GİRİŞ	Tamir Ücreti Tahsili	8333.00	26040102 nolu işlem tahsilatı.	126	2026-04-01 13:16:16.699565	Banko	26040102
185	ÇIKIŞ	Mal Alımı	68.00	Usta Siparişi Alımı: Vida | Adet: 1 | Birim: 68 ₺	\N	2026-04-01 13:21:11.154646	Banko Stok Girişi	\N
186	GİRİŞ	Stok Satışı	86.00	Stok Satışı: Vida | Adet: 1 | Birim: 86 ₺	\N	2026-04-01 13:22:53.046005	Barkod Satış	\N
187	ÇIKIŞ	Mal Alımı	570.00	Genel Stok Alımı: Vida | Adet: 10 | Birim: 57 ₺	\N	2026-04-01 13:46:49.308446	Banko Stok Girişi	\N
188	ÇIKIŞ	Mal Alımı	57.00	Hızlı İşlem Radarı (+1): Vida | Adet: 1 | Birim: 57 ₺	\N	2026-04-01 13:47:20.834276	Banko Stok Girişi	\N
189	ÇIKIŞ	Mal Alımı	195.00	Usta Siparişi Alımı: Somun | Adet: 3 | Birim: 65 ₺	\N	2026-04-01 13:48:55.622411	Banko Stok Girişi	\N
190	GİRİŞ	Stok Satışı	784.00	Stok Satışı: Somun | Adet: 8 | Birim: 98 ₺	\N	2026-04-01 13:54:46.608671	Barkod Satış	\N
191	ÇIKIŞ	Mal Alımı	72.00	Genel Stok Alımı: Somun | Adet: 1 | Birim: 72 ₺	\N	2026-04-01 14:06:44.973675	Banko Stok Girişi	\N
192	GİRİŞ	Stok Satışı	108.00	Stok Satışı: Somun | Adet: 1 | Birim: 108 ₺	\N	2026-04-01 15:24:26.695924	Barkod Satış	\N
193	GİRİŞ	Stok Satışı	108.00	Stok Satışı: Somun | Adet: 1 | Birim: 108 ₺	\N	2026-04-01 15:25:41.680928	Barkod Satış	\N
194	GİRİŞ	Stok Satışı	108.00	Stok Satışı: Somun | Adet: 1 | Birim: 108 ₺	\N	2026-04-01 15:32:02.21784	Barkod Satış	\N
195	GİRİŞ	Stok Satışı	1080.00	Stok Satışı: Somun | Adet: 10 | Birim: 108 ₺	\N	2026-04-01 15:51:03.280999	Barkod Satış	\N
196	ÇIKIŞ	Mal Alımı	864.00	Genel Stok Alımı: Somun | Adet: 12 | Birim: 72 ₺	\N	2026-04-01 15:52:57.607731	Banko Stok Girişi	\N
197	GİRİŞ	Stok Satışı	104.00	Stok Satışı: Somun (%20 İskonto) | Adet: 1 | Birim: 104 ₺	\N	2026-04-01 16:14:46.762681	Barkod Satış	\N
198	GİRİŞ	Stok Satışı	104.00	Stok Satışı: Somun (%20 İskonto) | Adet: 1 | Birim: 104 ₺	\N	2026-04-01 16:21:03.937884	Barkod Satış	\N
199	GİRİŞ	Stok Satışı	91.00	Stok Satışı: Somun (%20 İskonto) | Adet: 1 | Birim: 91 ₺	\N	2026-04-01 16:30:01.234044	Barkod Satış	\N
200	ÇIKIŞ	Mal Alımı	72.00	Hızlı İşlem Radarı (+1): Somun | Adet: 1 | Birim: 72 ₺	\N	2026-04-01 16:30:53.316257	Banko Stok Girişi	\N
201	ÇIKIŞ	Mal Alımı	2222.00	Hızlı İşlem Radarı (+1): Biber | Adet: 1 | Birim: 2222 ₺	\N	2026-04-01 16:32:58.281402	Banko Stok Girişi	\N
202	ÇIKIŞ	Mal Alımı	2222.00	Hızlı İşlem Radarı (+1): Biber | Adet: 1 | Birim: 2222 ₺	\N	2026-04-01 16:33:56.491811	Banko Stok Girişi	\N
203	GİRİŞ	Stok Satışı	3333.00	Stok Satışı: Biber | Adet: 1 | Birim: 3333 ₺	\N	2026-04-01 16:34:30.661587	Barkod Satış	\N
204	GİRİŞ	Stok Satışı	2000.00	Stok Satışı: Biber (%50 İskonto) | Adet: 1 | Birim: 2000 ₺	\N	2026-04-01 16:35:36.037261	Barkod Satış	\N
205	GİRİŞ	Stok Satışı	3000.00	Stok Satışı: Biber (%50 İskonto) | Adet: 1 | Birim: 3000 ₺	\N	2026-04-01 16:58:51.618413	Barkod Satış	\N
206	GİRİŞ	Stok Satışı	3333.00	Stok Satışı: Biber | Adet: 1 | Birim: 3333 ₺	\N	2026-04-01 17:00:01.86242	Barkod Satış	\N
207	ÇIKIŞ	Mal Alımı	5500.00	Genel Stok Alımı: Biber | Adet: 11 | Birim: 500 ₺	\N	2026-04-01 17:08:10.077042	Banko Stok Girişi	\N
208	GİRİŞ	Stok Satışı	3750.00	Stok Satışı: Biber | Adet: 5 | Birim: 750 ₺	\N	2026-04-01 17:17:35.060044	Barkod Satış	\N
209	GİRİŞ	Stok Satışı	36000.00	Stok Satışı: Ekran ipad | Adet: 2 | Birim: 18000 ₺	\N	2026-04-01 17:19:43.253475	Barkod Satış	\N
210	GİRİŞ	Stok Satışı	54000.00	Stok Satışı: Ekran ipad | Adet: 3 | Birim: 18000 ₺	\N	2026-04-01 17:25:54.838445	Barkod Satış	\N
211	GİRİŞ	Stok Satışı	18000.00	Stok Satışı: Ekran ipad | Adet: 1 | Birim: 18000 ₺	\N	2026-04-01 17:36:52.918459	Barkod Satış	\N
212	GİRİŞ	Kasaya Nakit Girişi	25088.00	Duz	\N	2026-04-01 17:40:56.672575	Admin	\N
213	GİRİŞ	Kasaya Nakit Girişi	9000.00	Ggg	\N	2026-04-01 17:41:23.062713	Admin	\N
214	GİRİŞ	Kasaya Nakit Girişi	5500.00	Tt	\N	2026-04-01 18:57:00.343958	Admin	\N
215	GİRİŞ	Kasaya Nakit Girişi	2500.00	Hayirli olsun	\N	2026-04-02 19:41:43.350453	Admin	\N
216	ÇIKIŞ	Mal Alımı	2500.00	Hızlı İşlem Radarı (+1): Apple cep | Adet: 1 | Birim: 2500 ₺	\N	2026-04-02 19:43:03.098566	Banko Stok Girişi	\N
217	GİRİŞ	Stok Satışı	3750.00	Stok Satışı: Apple cep | Adet: 1 | Birim: 3750 ₺	\N	2026-04-02 19:43:56.211016	Barkod Satış	\N
218	GİRİŞ	Stok Satışı	7500.00	Stok Satışı: Apple cep | Adet: 2 | Birim: 3750 ₺	\N	2026-04-02 19:49:32.123642	Barkod Satış	\N
219	GİRİŞ	Stok Satışı	3375.00	Stok Satışı: Apple cep (%50 İskonto) | Adet: 1 | Birim: 3375 ₺	\N	2026-04-02 19:50:36.213656	Barkod Satış	\N
220	ÇIKIŞ	Genel Gider Çıkışı	55.00	Acil	\N	2026-04-02 23:05:06.78896	Sistem	\N
221	ÇIKIŞ	Genel Gider Çıkışı	8888.00	Ceza	\N	2026-04-02 23:05:41.633592	Sistem	\N
222	ÇIKIŞ	Genel Gider Çıkışı	1.00	F	\N	2026-04-02 23:13:22.422926	Sistem	\N
223	ÇIKIŞ	Genel Gider Çıkışı	2.00	T	\N	2026-04-02 23:14:12.803396	Sistem	\N
224	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	999.00	Stok Alımı: Apple cep (5 Adet)	\N	2026-04-02 23:16:51.177749	Sistem	\N
225	ÇIKIŞ	Genel Gider Çıkışı	880.00	Gsgdgd	\N	2026-04-02 23:36:03.138712	Sistem	\N
226	ÇIKIŞ	Genel Gider Çıkışı	222.00	Hg	\N	2026-04-02 23:36:21.875415	Sistem	\N
227	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	2500.00	Stok Alımı: Biber (5 Adet)	\N	2026-04-02 23:37:48.703968	Sistem	\N
228	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	1500.00	Stok Alımı: Biber (2 Adet)	\N	2026-04-02 23:39:20.069754	Sistem	\N
229	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	250.00	Stok Alımı: Biber (1 Adet)	\N	2026-04-02 23:40:02.3194	Sistem	\N
230	ÇIKIŞ	Genel Gider Çıkışı	1.00	W	\N	2026-04-02 23:45:04.58139	Sistem	\N
231	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	1000.00	Stok Alımı: Biber (2 Adet)	\N	2026-04-02 23:46:33.980353	Sistem	\N
232	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	750.00	Stok Alımı: Biber (1 Adet)	\N	2026-04-02 23:47:23.499515	Sistem	\N
233	ÇIKIŞ	Diğer Giderler	450.00	Avans	\N	2026-04-02 23:48:35.27726	Sistem	\N
234	ÇIKIŞ	Genel Gider Çıkışı	1.00	F	\N	2026-04-02 23:54:40.631185	Sistem	\N
235	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	2500.00	Stok Alımı: Biber (5 Adet)	\N	2026-04-02 23:55:34.160009	Sistem	\N
236	ÇIKIŞ	Toptancıya Ödeme / Stok Alımı	3750.00	Stok Alımı: Biber (5 Adet)	\N	2026-04-02 23:56:13.433273	Sistem	\N
237	ÇIKIŞ	Genel Gider Çıkışı	2.00	Hh	\N	2026-04-03 00:05:17.446885	Sistem	\N
238	ÇIKIŞ	Mal Alımı	2500.00	Genel Stok Alımı: Biber | Adet: 5 | Birim: 500 ₺	\N	2026-04-03 00:06:05.995005	Banko Stok Girişi	\N
239	ÇIKIŞ	Mal Alımı	3750.00	Genel Stok Alımı: Biber | Adet: 5 | Birim: 750 ₺	\N	2026-04-03 00:07:08.892724	Banko Stok Girişi	\N
241	GİRİŞ	Kasaya Nakit Girişi	1500.00	Ggh	\N	2026-04-03 00:10:04.339001	Admin	\N
242	GİRİŞ	Kasaya Nakit Girişi	48.00	Gegegdbe	\N	2026-04-03 10:23:43.182795	Admin	\N
243	GİRİŞ	Kasaya Nakit Girişi	85.00	Bbb	\N	2026-04-03 11:16:08.180019	Admin	\N
244	ÇIKIŞ	Mal Alımı	3000.00	Genel Stok Alımı: Ekran karti1 | Adet: 2 | Birim: 1500 ₺	\N	2026-04-03 12:26:44.604235	Banko Stok Girişi	\N
245	GİRİŞ	Stok Satışı	2250.00	Stok Satışı: Ekran karti1 | Adet: 1 | Birim: 2250 ₺	\N	2026-04-03 12:41:06.227477	Barkod Satış	\N
246	GİRİŞ	Stok Satışı	2025.00	Stok Satışı: Ekran karti1 (%50 İskonto) | Adet: 1 | Birim: 2025 ₺	\N	2026-04-03 12:43:24.87098	Barkod Satış	\N
247	ÇIKIŞ	Mal Alımı	4500.00	Hızlı İşlem Radarı (+1): Hardisk | Adet: 1 | Birim: 4500 ₺	\N	2026-04-03 15:58:31.475699	Banko Stok Girişi	\N
248	GİRİŞ	Stok Satışı	6750.00	Stok Satışı: Hardisk | Adet: 1 | Birim: 6750 ₺	\N	2026-04-03 15:59:22.893431	Barkod Satış	\N
249	ÇIKIŞ	Mal Alımı	4500.00	Genel Stok Alımı: Hardisk | Adet: 1 | Birim: 4500 ₺	\N	2026-04-03 16:07:28.437048	Banko Stok Girişi	\N
250	ÇIKIŞ	Mal Alımı	4500.00	Usta Siparişi Alımı: Hardisk | Adet: 1 | Birim: 4500 ₺	\N	2026-04-03 16:37:12.674825	Banko Stok Girişi	\N
251	ÇIKIŞ	Mal Alımı	7600.00	Usta Siparişi Alımı: Ram | Adet: 2 | Birim: 3800 ₺	\N	2026-04-03 17:00:02.708639	Banko Stok Girişi	\N
252	ÇIKIŞ	Mal Alımı	7050.00	Usta Siparişi Alımı: Ekran | Adet: 1 | Birim: 7050 ₺	\N	2026-04-03 17:03:24.573454	Banko Stok Girişi	\N
253	GİRİŞ	Stok Satışı	25380.00	Stok Satışı: Hardisk (%30 İskonto) | Adet: 4 | Birim: 6345 ₺	\N	2026-04-03 17:14:35.296899	Barkod Satış	\N
254	GİRİŞ	Tamir Ücreti Tahsili	2333.00	26040103 nolu işlem tahsilatı.	127	2026-04-04 09:54:54.03129	Banko	26040103
255	GİRİŞ	Stok Satışı	4125.00	Stok Satışı: Ekmek | Adet: 1 | Birim: 4125 ₺	\N	2026-04-04 12:34:22.463888	Barkod Satış	\N
256	GİRİŞ	Tamir Ücreti Tahsili	1875.00	26040404 nolu işlem tahsilatı.	130	2026-04-04 14:31:51.196453	Banko	26040404
257	GİRİŞ	Tamir Ücreti Tahsili	3825.00	26040403 nolu işlem tahsilatı.	129	2026-04-04 14:42:16.855771	Banko	26040403
258	GİRİŞ	Randevu Geliri Tahsili	1800.00	26040405 nolu işlem tahsilatı.	113	2026-04-04 14:55:50.376731	Banko	26040405
259	GİRİŞ	Randevu Geliri Tahsili	11250.00	26040406 nolu işlem tahsilatı.	114	2026-04-04 15:08:03.408006	Banko	26040406
260	GİRİŞ	Stok Satışı	4125.00	Stok Satışı: Ekmek | Adet: 1 | Birim: 4125 ₺	\N	2026-04-04 15:14:49.013402	Barkod Satış	\N
261	GİRİŞ	Stok Satışı	2228.00	Stok Satışı: Ekran karti1 (%5 İskonto) | Adet: 1 | Birim: 2228 ₺	\N	2026-04-04 15:15:55.482242	Barkod Satış	\N
262	ÇIKIŞ	Mal Alımı	2400.00	Usta Siparişi Alımı: Razor | Adet: 2 | Birim: 1200 ₺	\N	2026-04-05 12:30:21.176538	Banko Stok Girişi	\N
263	ÇIKIŞ	Mal Alımı	1650.00	Usta Siparişi Alımı: Kesme bicagi | Adet: 3 | Birim: 550 ₺	\N	2026-04-05 12:32:23.916617	Banko Stok Girişi	\N
264	GİRİŞ	Tamir Ücreti Tahsili	11666.00	26040501 nolu işlem tahsilatı.	131	2026-04-05 12:35:12.097295	Banko	26040501
265	ÇIKIŞ	Mal Alımı	7000.00	Usta Siparişi Alımı: Elek | Adet: 1 | Birim: 7000 ₺	\N	2026-04-05 12:51:11.700903	Banko Stok Girişi	\N
266	GİRİŞ	Tamir Ücreti Tahsili	5000.00	26040502 nolu işlem tahsilatı.	132	2026-04-05 12:53:39.59147	Banko	26040502
267	ÇIKIŞ	Mal Alımı	7500.00	Usta Siparişi Alımı: Elek | Adet: 1 | Birim: 7500 ₺	\N	2026-04-05 13:04:17.288595	Banko Stok Girişi	\N
268	ÇIKIŞ	Mal Alımı	5000.00	Usta Siparişi Alımı: masa | Adet: 2 | Birim: 2500 ₺	\N	2026-04-05 15:40:09.419355	Banko Stok Girişi	\N
269	ÇIKIŞ	Mal Alımı	7600.00	Usta Siparişi Alımı: Ram | Adet: 2 | Birim: 3800 ₺	\N	2026-04-05 15:41:05.709365	Banko Stok Girişi	\N
270	ÇIKIŞ	Mal Alımı	7875.00	Usta Siparişi Alımı: Saksak | Adet: 15 | Birim: 525 ₺	\N	2026-04-05 15:43:16.064013	Banko Stok Girişi	\N
271	ÇIKIŞ	Mal Alımı	1777.00	Usta Siparişi Alımı: Resim | Adet: 1 | Birim: 1777 ₺	\N	2026-04-05 15:44:20.422749	Banko Stok Girişi	\N
272	GİRİŞ	Tamir Ücreti Tahsili	52500.00	26040505 nolu işlem tahsilatı.	135	2026-04-05 15:49:22.283339	Banko	26040505
273	GİRİŞ	Randevu Geliri Tahsili	7500.00	26040506 nolu işlem tahsilatı.	115	2026-04-05 16:16:22.35488	Banko	26040506
274	GİRİŞ	Kasaya Nakit Girişi	949.00	Bdbdbddh	\N	2026-04-06 21:37:30.797255	Admin	\N
275	GİRİŞ	Randevu Geliri Tahsili	31500.00	26040402 nolu işlem tahsilatı.	112	2026-04-07 15:45:29.761746	Banko	26040402
276	GİRİŞ	Randevu Geliri Tahsili	999.00	26040705 nolu işlem tahsilatı.	122	2026-04-07 15:53:41.333642	Banko	26040705
277	GİRİŞ	Randevu Geliri Tahsili	64500.00	26040704 nolu işlem tahsilatı.	121	2026-04-07 15:55:12.164064	Banko	26040704
278	GİRİŞ	Randevu Geliri Tahsili	1950.00	26040702 nolu işlem tahsilatı.	119	2026-04-07 15:55:23.165836	Banko	26040702
279	GİRİŞ	Kasaya Nakit Girişi	2555.00	Fff	\N	2026-04-09 18:18:18.643475	Admin	\N
280	ÇIKIŞ	Genel Gider Çıkışı	1000.00	Re	\N	2026-04-09 18:18:37.068113	Sistem	\N
281	GİRİŞ	Randevu Geliri Tahsili	1500.00	26040905 nolu işlem tahsilatı.	123	2026-04-09 18:54:29.299192	Banko	26040905
282	ÇIKIŞ	Mal Alımı	7500.00	Usta Siparişi Alımı: Labtop ekrani | Adet: 1 | Birim: 7500 ₺	\N	2026-04-10 18:56:10.773252	Banko Stok Girişi	\N
283	GİRİŞ	Stok Satışı	11250.00	Stok Satışı: Labtop ekrani | Adet: 1 | Birim: 11250 ₺	\N	2026-04-10 19:04:01.046129	Barkod Satış	\N
284	ÇIKIŞ	Mal Alımı	233.00	Usta Siparişi Alımı: Ketcap | Adet: 1 | Birim: 233 ₺	\N	2026-04-10 19:06:24.176143	Banko Stok Girişi	\N
285	GİRİŞ	Stok Satışı	350.00	Stok Satışı: Ketcap | Adet: 1 | Birim: 350 ₺	\N	2026-04-10 19:07:40.150003	Barkod Satış	\N
286	GİRİŞ	Tamir Ücreti Tahsili	11250.00	26040902 nolu işlem tahsilatı.	137	2026-04-10 19:22:53.895829	Banko	26040902
287	ÇIKIŞ	Mal Alımı	233.00	Usta Siparişi Alımı: Ketcap | Adet: 1 | Birim: 233 ₺	\N	2026-04-10 20:40:56.731851	Banko Stok Girişi	\N
288	GİRİŞ	Stok Satışı	350.00	Stok Satışı: Ketcap | Adet: 1 | Birim: 350 ₺	\N	2026-04-10 20:41:46.561214	Barkod Satış	\N
289	ÇIKIŞ	Mal Alımı	7500.00	Usta Siparişi Alımı: Labtop ekrani | Adet: 1 | Birim: 7500 ₺	\N	2026-04-10 20:43:03.153683	Banko Stok Girişi	\N
290	GİRİŞ	Stok Satışı	11250.00	Stok Satışı: Labtop ekrani | Adet: 1 | Birim: 11250 ₺	\N	2026-04-10 20:43:23.198191	Barkod Satış	\N
291	GİRİŞ	Tamir Ücreti Tahsili	3750.00	26041005 nolu işlem tahsilatı.	142	2026-04-10 23:36:12.443025	Banko	26041005
292	ÇIKIŞ	Mal Alımı	1500.00	Usta Siparişi Alımı: Ekran karti1 | Adet: 1 | Birim: 1500 ₺	\N	2026-04-11 00:41:08.494513	Banko Stok Girişi	\N
293	GİRİŞ	Stok Satışı	2250.00	Stok Satışı: Ekran karti1 | Adet: 1 | Birim: 2250 ₺	\N	2026-04-11 00:42:13.71716	Barkod Satış	\N
294	ÇIKIŞ	Mal Alımı	12000.00	Usta Siparişi Alımı: Ekran ipad | Adet: 1 | Birim: 12000 ₺	\N	2026-04-11 00:48:36.714155	Banko Stok Girişi	\N
295	GİRİŞ	Tamir Ücreti Tahsili	24000.00	26041002 nolu işlem tahsilatı.	141	2026-04-11 00:57:10.259024	Banko	26041002
296	ÇIKIŞ	Mal Alımı	15000.00	Genel Stok Alımı: Iphone ekrani 10 inch | Adet: 4 | Birim: 3750 ₺	\N	2026-04-12 17:59:49.775618	Banko Stok Girişi	\N
297	ÇIKIŞ	Mal Alımı	13740.00	Genel Stok Alımı: Iphone ekran 8 inch | Adet: 3 | Birim: 4580 ₺	\N	2026-04-12 18:00:52.368032	Banko Stok Girişi	\N
298	GİRİŞ	Randevu Geliri Tahsili	18000.00	26041218 nolu işlem tahsilatı.	142	2026-04-12 18:18:15.984435	Banko	26041218
299	GİRİŞ	Randevu Geliri Tahsili	69469.00	26041216 nolu işlem tahsilatı.	140	2026-04-12 18:37:35.779175	Banko	26041216
300	ÇIKIŞ	Mal Alımı	3000.00	Genel Stok Alımı: iphone ekran 6 inch | Adet: 3 | Birim: 1000 ₺	\N	2026-04-12 19:33:45.417653	Banko Stok Girişi	\N
301	ÇIKIŞ	Mal Alımı	466.00	Usta Siparişi Alımı: Ketcap | Adet: 2 | Birim: 233 ₺	\N	2026-04-12 20:47:40.632664	Banko Stok Girişi	\N
302	ÇIKIŞ	Mal Alımı	1500.00	Genel Stok Alımı: sarımsak | Adet: 10 | Birim: 150 ₺	\N	2026-04-12 23:19:07.533839	Banko Stok Girişi	\N
303	ÇIKIŞ	Mal Alımı	240.00	Genel Stok Alımı: Kasa | Adet: 24 | Birim: 10 ₺	\N	2026-04-13 14:11:09.492449	Banko Stok Girişi	\N
304	ÇIKIŞ	Mal Alımı	200.00	Usta Siparişi Alımı: Kasa | Adet: 5 | Birim: 40 ₺	\N	2026-04-13 14:17:24.359051	Banko Stok Girişi	\N
305	ÇIKIŞ	Mal Alımı	2500.00	Usta Siparişi Alımı: masa | Adet: 1 | Birim: 2500 ₺	\N	2026-04-13 14:39:44.122115	Banko Stok Girişi	\N
306	GİRİŞ	Tamir Ücreti Tahsili	14999.00	26041220 nolu işlem tahsilatı.	147	2026-04-13 14:44:58.077268	Banko	26041220
307	GİRİŞ	Kasaya Nakit Girişi	10000.00	Sebil	\N	2026-04-13 15:09:30.069195	Admin	\N
308	ÇIKIŞ	Genel Gider Çıkışı	25000.00	Ayse	\N	2026-04-13 15:09:50.380316	Sistem	\N
309	GİRİŞ	Tamir Ücreti Tahsili	27000.00	26041201 nolu işlem tahsilatı.	143	2026-04-13 15:42:05.594693	Banko	26041201
310	GİRİŞ	Randevu Geliri Tahsili	5000.00	26041219 nolu işlem tahsilatı.	143	2026-04-13 19:03:29.608837	Banko	26041219
311	ÇIKIŞ	Diğer Giderler	15000.00	Avans	\N	2026-04-13 19:22:54.310632	Sistem	\N
312	GİRİŞ	Kasaya Nakit Girişi	1500.00	ayşe avansı geri ödeme 1.taksit\n	\N	2026-04-14 10:31:15.313478	Banko	\N
313	GİRİŞ	Stok Satışı	12960.00	Stok Satışı: Hardisk (%20 İskonto) | Adet: 2 | Birim: 6480 ₺	\N	2026-04-14 11:39:32.666102	Barkod Satış	\N
314	ÇIKIŞ	Mal Alımı	11000.00	Genel Stok Alımı: hardisk | Adet: 2 | Birim: 5500 ₺	\N	2026-04-14 11:45:37.201876	Banko Stok Girişi	\N
315	GİRİŞ	Stok Satışı	8250.00	Stok Satışı: hardisk | Adet: 1 | Birim: 8250 ₺	\N	2026-04-14 11:48:19.923299	Barkod Satış	\N
316	GİRİŞ	Kasaya Nakit Girişi	1000.00	avans geri ödeme q1	\N	2026-04-14 11:56:42.031336	Banko	\N
317	GİRİŞ	Tamir Ücreti Tahsili	1800.00	26041204 nolu işlem tahsilatı.	146	2026-04-14 12:11:28.306644	Banko	26041204
318	GİRİŞ	Randevu Geliri Tahsili	11250.00	26041301 nolu işlem tahsilatı.	144	2026-04-14 12:14:21.644785	Banko	26041301
319	ÇIKIŞ	Mal Alımı	22000.00	Genel Stok Alımı: hardisk | Adet: 4 | Birim: 5500 ₺	\N	2026-04-14 12:26:56.742588	Banko Stok Girişi	\N
320	ÇIKIŞ	Mal Alımı	38500.00	Genel Stok Alımı: hardisk | Adet: 7 | Birim: 5500 ₺	\N	2026-04-14 13:07:41.002437	Banko Stok Girişi	\N
321	GİRİŞ	Kasaya Nakit Girişi	34750.00	Dışarıdan Kasaya Nakit Eklendi	\N	2026-04-14 13:08:33.764634	Banko	\N
322	ÇIKIŞ	Diğer Giderler	15000.00	ocak elektrik gideri	\N	2026-04-14 13:09:36.010037	Banko	\N
323	ÇIKIŞ	İade / Geri Ödeme	1000.00	hdd iade	\N	2026-04-14 13:11:54.53448	Banko	\N
324	ÇIKIŞ	Mal Alımı	5500.00	Genel Stok Alımı: hardisk | Adet: 1 | Birim: 5500 ₺	\N	2026-04-14 13:13:10.108489	Banko Stok Girişi	\N
325	ÇIKIŞ	İade / Geri Ödeme	1.00	işl	\N	2026-04-14 13:14:57.411102	Banko	\N
326	ÇIKIŞ	İade (Stok Satışı)	5500.00	İade (Stok Satışı): hardisk | Adet: 1 | Birim: 5500.00 ₺	\N	2026-04-14 13:26:59.654135	Banko Stok Girişi	\N
327	ÇIKIŞ	İade (Stok Satışı)	11000.00	İade (Stok Satışı): hardisk | Adet: 2 | İade Alış: 5500.00 ₺	\N	2026-04-14 13:34:52.838562	Banko Stok İade	\N
328	ÇIKIŞ	Genel İade	10001.00	dfsdf	\N	2026-04-14 13:43:53.821265	Banko	\N
329	ÇIKIŞ	Servis İptali	2000.00	gdfgdg	\N	2026-04-14 13:44:52.210777	Banko	26041220
330	ÇIKIŞ	Randevu İptali	22222.00	dfsf	\N	2026-04-14 13:45:30.706967	Banko	fgfdgfgfdg
331	ÇIKIŞ	Mal Alımı	5500.00	Genel Stok Alımı: hardisk | Adet: 1 | Birim: 5500 ₺	\N	2026-04-14 18:49:30.150345	Banko Stok Girişi	\N
332	ÇIKIŞ	Servis İptali	1000.00	26041220 nolu Servis İptali sebebiyle ücret iadesi yapıldı.	\N	2026-04-14 19:05:45.153314	Banko	\N
333	ÇIKIŞ	Servis İptali	12000.00	26041220 nolu Servis İptali sebebiyle ücret iadesi yapıldı.	\N	2026-04-14 19:09:12.643536	Banko	\N
334	ÇIKIŞ	Servis İptali	10000.00	26041220 nolu Servis İptali sebebiyle ücret iadesi yapıldı.	\N	2026-04-14 19:11:06.560057	Banko	\N
335	ÇIKIŞ	Servis İptali	1500.00	26041201 nolu Servis İptali sebebiyle müşteriye ücret iadesi yapıldı.   eksik ödeme yapıldı	\N	2026-04-14 19:40:15.740667	Banko	\N
336	ÇIKIŞ	Genel Gider Çıkışı	1000.00	det	\N	2026-04-14 19:43:58.427735	Banko	\N
337	ÇIKIŞ	Mal Alımı	5500.00	Genel Stok Alımı: hardisk | Adet: 1 | Birim: 5500 ₺	\N	2026-04-14 19:52:32.621871	Banko Stok Girişi	\N
338	ÇIKIŞ	Diğer Giderler	11.00	ask	\N	2026-04-14 19:53:12.22282	Banko	\N
339	ÇIKIŞ	Randevu İptali	31500.00	26040402 nolu Randevu İptali sebebiyle müşteriye ücret iadesi yapıldı.	\N	2026-04-14 20:08:02.736164	Banko	\N
340	ÇIKIŞ	Randevu İptali	31500.00	26040402 nolu Randevu İptali sebebiyle müşteriye ücret iadesi yapıldı.	\N	2026-04-14 20:10:23.14468	Banko	\N
341	ÇIKIŞ	Randevu İptali	31500.00	26040402 nolu Randevu İptali sebebiyle müşteriye ücret iadesi yapıldı.	\N	2026-04-14 20:13:43.285117	Banko	\N
342	ÇIKIŞ	Servis İptali	1000.00	26041204 nolu Servis İptali sebebiyle müşteriye ücret iadesi yapıldı.	\N	2026-04-14 20:24:44.14514	Banko	\N
343	GİRİŞ	Tamir Ücreti Tahsili	18000.00	26041203 nolu işlem tahsilatı.	145	2026-04-15 12:10:59.909563	Banko	26041203
344	GİRİŞ	Randevu Geliri Tahsili	8332.50	26041217 nolu işlem tahsilatı.	141	2026-04-15 12:11:15.656605	Banko	26041217
\.


--
-- Data for Name: material_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.material_requests (id, service_id, usta_email, part_name, quantity, description, status, created_at, stok_girisi_yapildi_mi) FROM stdin;
1	13	Usta_1	Hdd 1001	2	Cihaz: Efes - Not: Ssd111\n	Geldi	2026-03-16 16:43:07.563728	f
7	2	Usta_1	Lcd	7	Cihaz: Apple - Not: Se1	Geldi	2026-03-16 17:30:32.150723	f
6	8	Usta_1	Ekran	5	Cihaz: Lenovo - Not: As1	Geldi	2026-03-16 17:28:44.664191	f
5	5	Usta_1	Lamba	5	Cihaz: Xiaomi - Not: Q1	Geldi	2026-03-16 17:20:59.003409	f
9	8	Usta_1	Renk	1	Cihaz: Lenovo - Not: 1	Geldi	2026-03-16 20:16:44.824839	f
8	8	Usta_1	Alo	1	Cihaz: Lenovo - Not: Qq	Geldi	2026-03-16 20:16:44.809442	f
4	1	Usta_1	Fado	4	Cihaz: Apple - Not: 111	Geldi	2026-03-16 17:19:44.511735	f
3	6	Usta_1	Sensor	2	Cihaz: HP - Not: Yu1	Geldi	2026-03-16 17:17:59.267289	f
12	14	Usta_1	Hdhdhd	1	Cihaz: Efes - Not: Jdhdhd	Geldi	2026-03-16 20:37:09.371411	f
11	14	Usta_1	Hdhdhd	1	Cihaz: Efes - Not: Bshdh	Geldi	2026-03-16 20:37:09.353066	f
10	14	Usta_1	Gagagz	1	Cihaz: Efes - Not: Bshshs	Geldi	2026-03-16 20:37:09.333621	f
14	14	Usta_1	Nsnejdj	1	Cihaz: Efes - Not: Nshdhdh	Geldi	2026-03-16 20:38:52.091893	f
13	14	Usta_1	Hdhdhw	1	Cihaz: Efes - Not: Hshdj	Geldi	2026-03-16 20:38:51.91476	f
17	16	Usta_1	Vgghh	1	Cihaz: Apple - Not: Vvhh	Geldi	2026-03-16 21:13:16.818554	f
16	16	Usta_1	Dfffg	1	Cihaz: Apple - Not: Ggh	Geldi	2026-03-16 21:13:16.793069	f
19	18	Usta_1	Vvggj	1	Cihaz: Dell - Not: Bggg	Geldi	2026-03-16 21:24:26.719622	f
18	18	Usta_1	Fgvvg	1	Cihaz: Dell - Not: Bbvbj	Geldi	2026-03-16 21:24:26.690644	f
21	19	Usta_1	Bdhdhdh	1	Cihaz: Casped - Not: Hdhdhdh	Geldi	2026-03-16 21:38:27.489322	f
20	19	Usta_1	Gsgsg	1	Cihaz: Casped - Not: Hshdhdh	Geldi	2026-03-16 21:38:27.475052	f
23	20	Usta_1	sarı metal	3	Cihaz: hundai - Not: kırmızı	Geldi	2026-03-17 18:48:29.220361	f
22	20	Usta_1	kart1	1	Cihaz: hundai - Not: ss40	Geldi	2026-03-17 18:48:29.208807	f
24	4	Usta_1	tfdhfgh	5	Cihaz: Samsung - Not: trrtyutry	Geldi	2026-03-17 20:57:35.065553	f
29	3	Usta_1	ghfgh	1	Cihaz: Samsung - Not: ghfgh	Geldi	2026-03-17 21:27:25.919552	f
28	3	Usta_1	gfhfgh	1	Cihaz: Samsung - Not: ghgfh	Geldi	2026-03-17 21:27:25.91088	f
27	3	Usta_1	ghjghjgh	1	Cihaz: Samsung - Not: ghgfh	Geldi	2026-03-17 21:27:25.900679	f
2	8	Usta_1	Ekran	1	Cihaz: Lenovo - Not: Avags	Geldi	2026-03-16 17:07:55.665341	f
15	14	Usta_1	Ghh	1	Cihaz: Efes - Not: 	Geldi	2026-03-16 20:48:01.23226	f
34	74	Usta_1	Fis	1	Cihaz: Apple T10 - Not: 	Geldi	2026-03-22 22:29:15.602173	f
33	74	Usta_1	Kasa	1	Cihaz: Apple T10 - Not: 	Geldi	2026-03-22 22:29:15.588815	f
32	74	Usta_1	Ekean	1	Cihaz: Apple T10 - Not: 	Geldi	2026-03-22 22:29:15.567805	f
30	3	Usta_1	Gvvb	1	Cihaz: Samsung Galaxy S23 - Not: Ggh	Geldi	2026-03-17 22:06:26.182606	t
35	73	Usta_1	Disk	1	Cihaz: Samsung1 T21 - Not: 	Geldi	2026-03-22 22:32:00.805041	f
26	2	Usta_1	san	1	Cihaz: Apple - Not: sss	Geldi	2026-03-17 21:21:10.628858	t
25	2	Usta_1	masa	1	Cihaz: Apple - Not: ssss	Geldi	2026-03-17 21:21:10.616304	t
31	3	Usta_1	App1	1	Cihaz: Samsung Galaxy S23 - Not: Cam	Geldi	2026-03-21 20:41:30.805598	f
37	76	Usta_1	çer	3	Cihaz: Apple 1 - Not: kırmızı	Geldi	2026-03-23 14:40:37.487413	f
36	76	Usta_1	cam	2	Cihaz: Apple 1 - Not: sarı	Geldi	2026-03-23 14:40:37.475826	f
38	77	Usta_1	cam	1	Cihaz: Xiaomi Redmi Note 12 - Not: 1	Geldi	2026-03-23 15:38:54.4393	f
40	90	Usta_1	lehim	3	Cihaz: Alkatel Asl - Not: bakırlı	Geldi	2026-03-24 13:52:13.9623	f
39	90	Usta_1	anten teli	2	Cihaz: Alkatel Asl - Not: 1 metre	Geldi	2026-03-24 13:52:13.957212	f
42	116	Usta_1	Hehe	1	Cihaz: Apple T10 - Not: Bsbd	Geldi	2026-03-26 13:32:43.28886	f
41	116	Usta_1	Bddhdhd	1	Cihaz: Apple T10 - Not: Hshe	Geldi	2026-03-26 13:32:43.273675	f
43	119	Usta_1	M4 HDD (APPLE)	2	Cihaz: Apple M4 - Not: 512 SSD OLSUN	Geldi	2026-03-30 17:46:55.795258	f
53	126	Usta_1	Varyete	2	Siyah olacak	Geldi	2026-04-01 12:16:50.388565	t
52	126	Usta_1	Somun	25	Kirmizi olsun	Geldi	2026-04-01 12:16:50.362864	t
47	125	Usta_1	Ekmek	4	Cihaz: Zebra TC21 El Terminali - Not: Tahilli	Geldi	2026-04-01 11:12:29.975153	t
46	124	Usta_1	Mayonez	3	Cihaz: Casped 1 - Not: Yagsiz	Geldi	2026-03-31 20:04:37.529564	t
45	124	Usta_1	Ketcap	2	Cihaz: Casped 1 - Not: Mangal	Geldi	2026-03-31 20:04:37.515809	t
44	124	Usta_1	Hardal	1	Cihaz: Casped 1 - Not: Sari	Geldi	2026-03-31 20:04:37.490306	t
51	126	Usta_1	Vida	10	Yesil sari olacak	Geldi	2026-04-01 12:16:50.344023	t
49	125	Usta_1	Biber	5	Cihaz: Zebra TC21 El Terminali - Not: Kara	Geldi	2026-04-01 11:12:30.010802	f
50	125	Usta_1	Biber	1	Cihaz: Zebra TC21 El Terminali - Not: Kirmizi	Geldi	2026-04-01 11:12:30.026854	t
48	125	Usta_1	Tuz	2	Cihaz: Zebra TC21 El Terminali - Not: Kaya	Geldi	2026-04-01 11:12:29.993381	f
59	131	Usta_1	Kesme bicagi	3	Elekli	Geldi	2026-04-05 12:29:11.127599	t
63	135	Usta_1	Masa	2	Kirmizi	Geldi	2026-04-05 15:37:40.225144	t
58	127	Usta_1	Ekran	1	20 inch	Geldi	2026-04-03 16:24:11.008959	t
57	127	Usta_1	Ram	2	1600 luk	Geldi	2026-04-03 16:24:10.988867	t
55	127	Usta_1	Somun	3	Ortak v3	Geldi	2026-04-01 13:19:47.736592	t
54	127	Usta_1	Vida	1	Ortak	Geldi	2026-04-01 13:19:47.720481	t
66	134	Usta_1	Resim	1	Alma	Geldi	2026-04-05 15:38:38.28983	t
61	132	Usta_1	Elek	1	Krom	Geldi	2026-04-05 12:50:08.934405	t
56	127	Usta_1	Hdd	1	Ssd_1000gb	Geldi	2026-04-03 16:24:10.969201	t
60	131	Usta_1	Razor	2	Tras model	Geldi	2026-04-05 12:29:11.258048	t
65	134	Usta_1	Saksak	15	Yesil	Geldi	2026-04-05 15:38:37.669197	t
64	135	Usta_1	Ram	2	1200	Geldi	2026-04-05 15:37:40.246231	t
62	133	Usta_1	Elek	1	Tras	Geldi	2026-04-05 13:03:18.437615	t
70	142	Usta_1	Ketcap	1	Kirmizi	Geldi	2026-04-10 20:27:47.701165	t
67	137	Usta_1	Ekran	1	Sari	Geldi	2026-04-10 18:52:23.155671	t
69	142	Usta_1	Ekran	1	Sari	Geldi	2026-04-10 20:27:47.684728	t
68	137	Usta_1	Ketcap	1		Geldi	2026-04-10 18:52:23.1819	t
71	141	Usta_1	Ekran karti1	1		Geldi	2026-04-11 00:20:39.917869	t
72	141	Usta_1	Ekran ipad	1	Dev	Geldi	2026-04-11 00:43:53.719557	t
79	147	Usta_1	Kasa	10	Sari	Geldi	2026-04-13 13:41:21.840578	f
74	143	Usta_1	Ketcap	1		Geldi	2026-04-12 20:44:33.680893	t
75	143	Usta_1	Hardisk	1	3600	Geldi	2026-04-12 20:44:33.696927	f
76	143	Merkez (Patron)	Ddr ram 1600	2	ihtiyaç var	Geldi	2026-04-13 12:54:33.493482	f
73	143	Usta_1	iphone ekran 6 inch	1	2. El olur	Geldi	2026-04-12 20:44:33.664627	f
81	143	Usta_1	Kasa	3		Geldi	2026-04-13 14:03:34.918555	t
82	143	Usta_1	masa	1		Geldi	2026-04-13 14:03:34.937	t
83	143	Merkez (Patron)	Tornavida kısa 3mm	2	takip	Geldi	2026-04-13 14:35:51.27675	f
\.


--
-- Data for Name: price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.price_history (id, inventory_id, eski_alis, yeni_alis, eski_satis, yeni_satis, degisim_tarihi) FROM stdin;
1	9	94845845.00	4800.00	0.00	0.00	2026-03-30 20:00:33.689255
2	10	400.00	0.00	1250.00	1250.00	2026-03-31 10:07:16.060999
3	9	4800.00	5000.00	0.00	0.00	2026-03-31 10:11:35.089062
4	9	5000.00	0.00	0.00	0.00	2026-03-31 10:23:32.363337
5	9	0.00	2000.00	0.00	0.00	2026-03-31 11:31:04.950503
6	9	2000.00	0.00	0.00	0.00	2026-03-31 12:19:04.857076
7	9	0.00	3450.00	0.00	0.00	2026-03-31 12:24:57.371981
8	9	3450.00	0.00	0.00	0.00	2026-03-31 12:25:23.416452
9	9	0.00	2500.00	0.00	0.00	2026-03-31 12:27:28.671877
10	8	500.00	750.00	0.00	0.00	2026-03-31 13:02:47.984644
11	10	0.00	39.00	1250.00	1250.00	2026-03-31 13:45:40.678199
12	10	39.00	0.00	1250.00	1250.00	2026-03-31 13:46:57.533257
13	8	750.00	0.00	0.00	0.00	2026-03-31 17:59:48.587857
14	8	0.00	750.00	0.00	0.00	2026-03-31 18:10:07.260844
15	8	750.00	850.00	0.00	0.00	2026-03-31 18:10:16.758764
16	10	0.00	4500.00	1250.00	1250.00	2026-03-31 18:32:19.05754
17	8	850.00	1000.00	0.00	0.00	2026-03-31 18:56:31.763493
18	12	1000.00	2500.00	0.00	0.00	2026-03-31 19:45:30.913598
19	19	8.00	550.00	0.00	0.00	2026-03-31 19:50:26.3964
20	19	550.00	675.00	0.00	0.00	2026-03-31 19:55:39.538761
21	69	55.00	65.00	0.00	0.00	2026-04-01 13:48:55.622411
22	69	65.00	72.00	0.00	0.00	2026-04-01 14:06:44.973675
23	67	2222.00	500.00	0.00	0.00	2026-04-01 17:08:10.077042
24	67	500.00	750.00	0.00	0.00	2026-04-03 00:07:08.892724
25	94	7000.00	7500.00	0.00	0.00	2026-04-05 13:04:17.288595
26	94	7500.00	85.00	0.00	0.00	2026-04-05 14:14:32.538429
27	99	1777.00	1800.00	0.00	0.00	2026-04-06 21:18:33.222764
28	99	1800.00	2000.00	0.00	0.00	2026-04-06 21:32:11.665835
29	99	2000.00	2100.00	0.00	0.00	2026-04-06 21:32:37.493838
30	99	2100.00	4000.00	0.00	0.00	2026-04-06 21:32:50.041933
31	66	2750.00	20.00	0.00	0.00	2026-04-06 21:33:10.951606
32	66	20.00	1750.00	0.00	0.00	2026-04-06 21:35:08.158034
33	66	1750.00	500.00	0.00	0.00	2026-04-06 21:35:36.876026
34	66	500.00	1000.00	0.00	0.00	2026-04-06 21:36:03.750464
35	4	2500.00	7500.00	0.00	0.00	2026-04-10 18:56:10.773252
36	62	233.00	500.00	0.00	0.00	2026-04-13 13:05:05.14481
37	7	4.00	10.00	0.00	0.00	2026-04-13 14:06:42.269657
38	7	10.00	40.00	0.00	0.00	2026-04-13 14:13:27.188344
39	10	4500.00	5500.00	1250.00	1250.00	2026-04-14 11:45:37.201876
\.


--
-- Data for Name: service_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_notes (id, service_id, note_text, created_at) FROM stdin;
1	1	Müşteri ekranın orijinal olmasını özellikle rica etti.	2026-03-16 13:51:59.675381
2	2	Şarj soketi içi toz dolu, temizlik denenecek.	2026-03-16 13:51:59.675381
3	3	Sıvı teması eski tarihli, korozyon başlangıcı var.	2026-03-16 13:51:59.675381
4	6	Firma acil olduğunu, yedek cihaz gerekebileceğini belirtti.	2026-03-16 13:51:59.675381
5	7	Yazılım kaynaklı olabilir, yedek alınıp format atılacak.	2026-03-16 13:51:59.675381
6	10	Kağıt alma silindiri (pickup roller) aşınmış görünüyor.	2026-03-16 13:51:59.675381
7	13	Kemal Müdür: Hdd 1001 teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 16:43:42.196526
8	2	Kemal Müdür: Lcd teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 17:31:50.817487
9	8	Kemal Müdür: Ekran teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 17:32:09.876166
10	5	Kemal Müdür: Lamba teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 17:32:12.477217
11	8	Kemal Müdür: Renk teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:19:26.701038
12	8	Kemal Müdür: Alo teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:30:36.543283
13	1	Kemal Müdür: Fado teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:30:41.21065
14	6	Kemal Müdür: Sensor teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:34:23.49942
15	14	Kemal Müdür: Hdhdhd teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:37:41.501152
16	14	Kemal Müdür: Hdhdhd teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:37:53.905408
17	14	Kemal Müdür: Gagagz teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:37:59.461149
18	14	Kemal Müdür: Nsnejdj teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:45:28.662275
19	14	Kemal Müdür: Hdhdhw teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 20:45:33.008663
20	16	Kemal Müdür: Vgghh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:13:46.018726
21	16	Kemal Müdür: Dfffg teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:13:48.853907
22	18	Kemal Müdür: Vvggj teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:24:47.010839
23	18	Kemal Müdür: Fgvvg teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:24:50.612272
24	19	Kemal Müdür: Bdhdhdh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:38:48.041715
25	19	Kemal Müdür: Gsgsg teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 21:38:50.725897
26	20	Kemal Müdür: sarı metal teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 18:48:55.590288
27	20	Kemal Müdür: kart1 teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 18:48:59.521723
28	4	Kemal Müdür: tfdhfgh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 20:58:10.174868
29	3	Kemal Müdür: ghfgh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 21:27:38.218496
30	3	Kemal Müdür: gfhfgh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 21:27:41.619989
31	3	Kemal Müdür: ghjghjgh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 21:27:44.90221
32	8	Kemal Müdür: Ekran teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 21:30:27.640154
33	14	Kemal Müdür: Ghh teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-17 21:30:32.763888
34	3	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-21 20:02:40.256584
35	3	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-21 20:32:53.616149
36	3	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-21 20:34:18.801469
37	3	Kemal Müdür: Gvvb teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-21 20:34:42.475692
38	2	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-21 20:48:05.547064
39	2	Kemal Müdür: san teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-21 20:48:26.404676
40	2	Kemal Müdür: masa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-22 22:13:33.4152
41	3	Kemal Müdür: App1 teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-22 22:13:37.166031
42	74	Kemal Müdür: Fis teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-22 22:30:58.4277
43	74	Kemal Müdür: Kasa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-22 22:31:02.359259
44	74	Kemal Müdür: Ekean teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-22 22:31:07.859115
45	73	Kemal Müdür: Disk teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-23 14:41:45.744046
46	76	Kemal Müdür: çer teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-23 14:41:52.713756
47	76	Kemal Müdür: cam teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-23 14:41:56.248495
48	77	Kemal Müdür: cam teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-23 15:39:07.328216
49	90	Kemal Müdür: lehim teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-24 13:53:31.958264
50	90	Kemal Müdür: anten teli teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-24 13:53:35.309288
51	116	Kemal Müdür: Hehe teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-26 13:33:38.700464
52	116	Kemal Müdür: Bddhdhd teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-26 13:33:41.701038
53	119	Kemal Müdür: M4 HDD (APPLE) teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-30 17:55:56.569096
54	124	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-31 20:05:42.505938
55	124	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-31 20:06:41.530383
56	124	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-31 20:07:55.973548
57	124	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-31 20:18:07.125835
58	124	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-03-31 20:51:21.486284
59	124	Kemal Müdür: Mayonez teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 11:07:49.65412
60	124	Kemal Müdür: Ketcap teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 11:07:52.621336
61	124	Kemal Müdür: Hardal teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 11:07:55.535583
62	125	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 11:18:49.86632
63	125	Kemal Müdür: Ekmek teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 11:20:37.338442
64	125	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 11:21:56.714413
65	125	Kemal Müdür: Biber teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 12:11:49.686826
66	125	Kemal Müdür: Biber teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 12:11:53.208893
67	125	Kemal Müdür: Tuz teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 12:11:57.605703
68	126	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 12:18:25.256616
69	126	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 12:25:28.686655
70	126	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 13:10:51.806416
71	126	Kemal Müdür: Varyete teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 13:14:32.967234
72	126	Kemal Müdür: Somun teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 13:14:35.364716
73	126	Kemal Müdür: Vida teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 13:14:37.987726
74	127	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 13:21:11.154646
75	127	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-01 13:48:55.622411
76	127	Kemal Müdür: Somun teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 13:50:08.066831
77	127	Kemal Müdür: Vida teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-01 13:50:16.811616
78	127	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-03 16:37:12.674825
79	127	Kemal Müdür: Hdd teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-03 16:57:00.298385
80	127	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-03 17:00:02.708639
81	127	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-03 17:03:24.573454
82	127	Kemal Müdür: Ekran teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-03 17:05:42.034552
83	127	Kemal Müdür: Ram teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-03 17:05:44.933921
84	131	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 12:30:21.176538
85	131	Kemal Müdür: Razor teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 12:31:34.42059
86	131	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 12:32:23.916617
87	131	Kemal Müdür: Kesme bicagi teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 12:33:51.604895
88	132	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 12:51:11.700903
89	132	Kemal Müdür: Elek teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 12:51:42.230856
90	133	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 13:04:17.288595
91	133	Kemal Müdür: Elek teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 13:04:55.937996
92	135	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 15:40:09.419355
93	135	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 15:41:05.709365
94	135	Kemal Müdür: Ram teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 15:42:08.315273
95	135	Kemal Müdür: Masa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 15:42:10.677904
96	134	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 15:43:16.064013
97	134	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-05 15:44:20.422749
98	134	Kemal Müdür: Resim teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 15:45:03.682763
99	134	Kemal Müdür: Saksak teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-05 15:45:07.879828
100	137	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-10 18:56:10.773252
101	137	Kemal Müdür: Ekran teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-10 19:04:59.325926
102	137	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-10 19:06:24.176143
103	137	Kemal Müdür: Ketcap teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-10 19:09:29.529083
104	142	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-10 20:40:56.731851
105	142	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-10 20:43:03.153683
106	142	Kemal Müdür: Ketcap teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-10 20:46:01.382835
107	142	Kemal Müdür: Ekran teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-10 20:46:06.630661
108	141	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-11 00:41:08.494513
109	141	Kemal Müdür: Ekran karti1 teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-11 00:42:57.243642
110	141	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-11 00:48:36.714155
111	141	Kemal Müdür: Ekran ipad teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-11 00:49:17.885578
112	143	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-12 20:47:40.632664
113	143	Kemal Müdür: Ketcap teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-12 20:48:42.046685
114	143	Kemal Müdür: iphone ekran 6 inch teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:01:33.530786
115	143	Kemal Müdür: Hardisk teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:01:48.411797
116	143	Kemal Müdür: Ddr ram 1600 teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:01:52.028743
117	147	Kemal Müdür: Kasa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:07:14.939945
118	143	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-13 14:17:24.359051
119	143	Kemal Müdür: Kasa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:18:50.757393
120	143	LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.	2026-04-13 14:39:44.122115
121	143	Kemal Müdür: masa teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:41:40.429039
122	143	Kemal Müdür: Tornavida kısa 3mm teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-04-13 14:41:44.952839
\.


--
-- Data for Name: service_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_records (id, customer_id, device_id, fault_description, status, technician_note, price, created_at) FROM stdin;
\.


--
-- Data for Name: service_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_status_history (id, service_id, old_status, new_status, changed_by, note, changed_at) FROM stdin;
1	13	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2500 TL fiyat verdi	2026-03-16 16:40:40.351534
2	13	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:42:21.467467
3	13	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:42:30.281269
4	13	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:42:33.393815
5	13	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:42:37.064239
6	13	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:44:29.994921
7	13	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:44:33.502172
8	13	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:44:37.94644
9	8	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 16:51:49.049054
10	8	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:17:03.588441
11	6	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:17:20.726987
12	1	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:19:25.548395
13	5	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:20:42.683743
14	8	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:28:18.383141
15	2	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:29:54.775086
16	6	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 17:37:07.741899
17	11	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 8200 TL fiyat verdi	2026-03-16 17:39:17.332113
18	8	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:15:57.397457
19	14	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 12000 TL fiyat verdi	2026-03-16 20:35:47.965473
20	14	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:36:30.783636
21	14	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:36:34.687952
22	14	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:38:31.46999
23	14	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:47:52.880916
24	14	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 20:56:00.216305
25	15	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 3500 TL fiyat verdi	2026-03-16 21:03:13.305906
26	15	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:04:14.42944
27	14	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:07:12.570487
28	16	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-16 21:09:35.479286
29	16	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:12:46.1368
30	16	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:12:52.686111
31	16	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:14:12.831715
32	17	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1000 TL fiyat verdi	2026-03-16 21:17:28.795655
33	17	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:18:11.287022
34	17	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:18:17.762224
35	18	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-16 21:23:23.467475
36	18	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:23:56.324454
37	18	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:24:02.206716
38	18	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:28:08.458364
39	19	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2000 TL fiyat verdi	2026-03-16 21:37:29.982866
40	19	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:38:03.047082
41	19	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:38:27.503022
42	19	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:39:26.887102
43	1	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:47:55.134547
44	15	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:47:57.176376
45	8	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:48:04.427023
46	6	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:48:08.369505
47	5	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 21:48:12.052975
48	4	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1000 TL fiyat verdi	2026-03-17 12:15:25.953237
49	4	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-17 12:16:14.86197
50	20	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 15000 TL fiyat verdi	2026-03-17 18:26:14.679188
51	20	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-17 18:35:47.504941
52	20	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-17 18:48:29.239971
53	20	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-17 18:49:22.543143
54	4	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-17 20:57:35.078053
55	2	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-17 21:21:10.648854
56	2	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 4000 TL fiyat verdi	2026-03-17 21:23:02.327206
57	3	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-17 21:27:25.937854
58	14	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-17 21:31:35.38069
59	8	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-17 21:31:39.842386
60	3	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-17 22:06:26.201779
61	71	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1000 TL fiyat verdi	2026-03-20 23:23:17.781098
62	63	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5000 TL fiyat verdi	2026-03-20 23:24:32.511482
63	71	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-20 23:25:19.918984
64	3	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-21 20:41:30.823588
65	60	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2500 TL fiyat verdi	2026-03-21 20:42:06.187772
66	3	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:14:13.273437
67	2	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:14:16.870641
68	74	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 10000 TL fiyat verdi	2026-03-22 22:22:18.880083
69	73	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5000 TL fiyat verdi	2026-03-22 22:22:42.299274
70	74	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:26:22.827429
71	74	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:29:15.6336
72	73	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:29:26.351084
73	73	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:32:00.859504
74	74	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-22 22:33:51.190414
75	76	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2000 TL fiyat verdi	2026-03-23 14:39:20.717303
76	76	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-23 14:39:48.913823
77	76	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-23 14:40:37.50238
78	76	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-23 14:42:25.991282
79	73	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-23 14:44:06.396207
80	77	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 12000 TL fiyat verdi	2026-03-23 15:38:16.640321
81	77	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-23 15:38:40.890191
82	77	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-23 15:38:54.455653
83	77	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-23 15:39:20.056254
84	79	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2345 TL fiyat verdi	2026-03-23 16:07:41.060954
85	80	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 50 TL fiyat verdi	2026-03-23 16:12:54.644089
86	81	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1 TL fiyat verdi	2026-03-23 17:17:12.88427
87	82	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1750 TL fiyat verdi	2026-03-23 17:25:49.315339
88	83	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 100 TL fiyat verdi	2026-03-23 17:43:16.366674
89	85	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 4000 TL fiyat verdi	2026-03-23 18:33:44.202259
90	86	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 10000 TL fiyat verdi	2026-03-23 18:52:51.276736
91	88	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 120000 TL fiyat verdi	2026-03-24 00:31:37.017321
92	88	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 00:31:53.095616
93	88	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 00:31:56.072861
94	84	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5001 TL fiyat verdi	2026-03-24 12:11:56.944085
95	84	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 12:12:21.828559
96	84	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 12:12:23.526536
97	89	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5005 TL fiyat verdi	2026-03-24 12:25:53.918589
98	89	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 12:26:13.392505
99	89	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 12:26:14.96686
100	90	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 3500 TL fiyat verdi	2026-03-24 13:50:10.937749
101	90	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 13:50:58.300043
102	90	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-24 13:52:13.964441
103	90	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 13:54:23.469492
104	91	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 501 TL fiyat verdi	2026-03-24 13:57:40.912975
105	91	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 13:57:58.421148
106	91	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 13:57:59.35615
107	92	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 11 TL fiyat verdi	2026-03-24 14:01:20.931482
108	93	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 6666 TL fiyat verdi	2026-03-24 14:03:20.745088
109	95	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 0 TL fiyat verdi	2026-03-24 14:17:39.003836
110	97	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 123 TL fiyat verdi	2026-03-24 14:22:08.721702
111	98	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 9999 TL fiyat verdi	2026-03-24 14:23:35.25035
112	98	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 14:23:58.481235
113	98	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 14:23:59.87209
114	99	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1 TL fiyat verdi	2026-03-24 14:26:51.563553
115	99	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 14:27:13.045914
116	99	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 14:27:14.025408
117	105	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2509 TL fiyat verdi	2026-03-24 18:07:40.366534
118	105	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 18:08:05.048883
119	105	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 18:08:06.060848
120	109	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1508 TL fiyat verdi	2026-03-24 21:44:19.193778
121	109	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-24 21:44:49.332001
122	109	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-24 21:44:52.585903
123	108	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 250 TL fiyat verdi	2026-03-25 18:46:06.119587
124	111	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 255 TL fiyat verdi	2026-03-25 18:46:22.040034
125	112	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 550 TL fiyat verdi	2026-03-25 18:56:13.093019
126	116	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-26 13:31:12.602813
127	116	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-26 13:32:20.746825
128	116	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-26 13:32:43.308261
129	116	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-26 13:34:04.315709
130	118	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-26 17:00:55.961876
131	119	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2750 TL fiyat verdi	2026-03-30 17:18:50.280099
132	119	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-30 17:42:56.441189
133	119	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-30 17:46:55.799948
134	119	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-30 17:59:47.746103
135	121	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 11000 TL fiyat verdi	2026-03-31 14:13:41.417821
136	123	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 7500 TL fiyat verdi	2026-03-31 14:35:10.930819
137	124	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 12500 TL fiyat verdi	2026-03-31 20:02:50.295896
138	124	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-31 20:03:27.765316
139	124	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-31 20:04:37.556732
140	124	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-01 11:08:30.860098
141	125	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 9999 TL fiyat verdi	2026-04-01 11:10:28.546623
142	125	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-01 11:10:55.024939
143	125	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-01 11:12:30.045168
144	125	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-01 12:13:01.235014
145	126	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5555 TL fiyat verdi	2026-04-01 12:13:16.743745
146	126	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-01 12:14:59.293567
147	126	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-01 12:16:50.414943
148	126	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-01 13:14:58.687686
149	127	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1555 TL fiyat verdi	2026-04-01 13:18:16.741187
150	127	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-01 13:18:49.169903
151	127	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-01 13:19:47.765534
152	127	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-03 16:24:11.02857
153	130	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1250 TL fiyat verdi	2026-04-04 14:25:46.742194
154	129	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2550 TL fiyat verdi	2026-04-04 14:36:14.556369
155	131	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 7777 TL fiyat verdi	2026-04-05 12:27:13.574214
156	131	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:27:42.998675
157	131	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:29:11.271107
158	131	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:34:03.728468
159	132	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 3333 TL fiyat verdi	2026-04-05 12:48:58.3602
160	132	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:49:37.331513
161	132	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:50:08.962651
162	132	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-05 12:51:52.575251
163	133	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2500 TL fiyat verdi	2026-04-05 13:01:55.549194
164	133	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-05 13:02:24.369545
165	133	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-05 13:03:18.463656
166	133	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-05 13:05:08.272114
167	135	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1000 TL fiyat verdi	2026-04-05 15:35:29.383424
168	134	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2000 TL fiyat verdi	2026-04-05 15:35:43.345189
169	134	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2000 TL fiyat verdi	2026-04-05 15:35:43.362909
170	135	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:36:26.972594
171	135	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:37:40.257893
172	134	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:37:43.815492
173	134	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:38:39.78587
174	135	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:45:37.064067
175	134	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-05 15:45:40.01332
176	141	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1001 TL fiyat verdi	2026-04-10 18:22:21.74821
177	137	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1002 TL fiyat verdi	2026-04-10 18:31:07.579709
178	138	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1003 TL fiyat verdi	2026-04-10 18:41:24.213909
179	141	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-10 18:43:13.642179
180	137	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-10 18:48:23.281624
181	137	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-10 18:52:23.246894
182	137	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-10 19:10:34.826233
183	142	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2500 TL fiyat verdi	2026-04-10 20:23:45.128578
184	142	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-10 20:25:20.63661
185	142	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-10 20:27:47.756188
186	142	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-10 20:47:03.38635
187	141	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-11 00:20:40.214137
188	141	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-11 00:43:53.765809
189	141	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-11 00:51:12.202535
190	140	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-11 13:18:03.974909
191	143	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 7500 TL fiyat verdi	2026-04-12 20:41:06.608107
192	143	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-12 20:42:24.052907
193	143	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-12 20:44:33.748426
194	143	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-13 12:57:21.564711
195	147	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 9999 TL fiyat verdi	2026-04-13 13:38:46.28613
196	147	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-04-13 13:39:19.019905
197	147	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-13 13:41:21.965605
198	143	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-04-13 14:03:34.994068
199	147	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-04-13 14:42:45.271708
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (id, device_id, issue_text, status, created_at, atanan_usta, servis_no, seri_no, garanti, musteri_notu, offer_price, expert_note, updated_at, customer_id, firm_id, yonetici_notu) FROM stdin;
1	1	Ekran kırık, görüntü tamamen yok.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031601	\N	\N	Müşteri cihazın daha önce hiç tamir görmediğini, titiz olduğunu belirtti.	0.00	Durum usta tarafından güncellendi	2026-03-17 20:57:05.912139	\N	\N	\N
18	7	Girik	Teslim Edildi	2026-03-16 21:23:06.090923	Usta 1	26031618	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:37.845459	\N	\N	\N
19	15	Isinma	Teslim Edildi	2026-03-16 21:36:57.534556	Usta 1	26031619	\N	\N	Isinma	2000.00	Durum usta tarafından güncellendi	2026-03-16 21:48:31.543982	\N	\N	\N
17	12	Kirik	Teslim Edildi	2026-03-16 21:17:00.926633	Usta 1	26031617	\N	\N		1000.00	Durum usta tarafından güncellendi	2026-03-16 21:30:44.766313	\N	\N	\N
16	11	Ekran	Teslim Edildi	2026-03-16 21:09:15.130386	Usta 1	26031616	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:51.424697	\N	\N	\N
15	14	Ses yok	Teslim Edildi	2026-03-16 21:02:40.626057	Usta 1	26031615	\N	\N	Micro	3500.00	Durum usta tarafından güncellendi	2026-03-16 21:48:38.730277	\N	\N	\N
13	13	Bozuk	Teslim Edildi	2026-03-16 16:40:05.494651	Usta 1	26031613	\N	\N	Kablo dahil geldi	2500.00	Durum usta tarafından güncellendi	2026-03-16 21:31:04.78975	\N	\N	\N
12	12	Wi-Fi sürekli kopuyor, sinyal çok zayıf.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031612	\N	\N	Bağlantı sorunu sadece ofis içinde oluyormuş.	0.00	\N	2026-03-16 21:31:09.823985	\N	\N	\N
7	7	Mavi ekran hatası (Kernel Panic).	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031607	\N	\N	Cihazın içinde önemli kurumsal veriler var, yedekleme istendi.	0.00	\N	2026-03-16 21:31:20.067573	\N	\N	\N
10	10	Kağıt sıkıştırıyor, çıktı üzerinde lekeler var.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031610	\N	\N	Yazıcı drum ünitesi daha yeni değişmiş, dikkat edilsin.	0.00	\N	2026-03-16 17:36:06.095674	\N	\N	\N
11	11	Batarya şişmiş, kasa esniyor.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031611	\N	\N	Ekranın sol üstünde hafif bir çatlak zaten vardı.	8200.00	Usta 8200 TL fiyat verdi	2026-03-16 21:48:51.527913	\N	\N	\N
14	13	Bozuk	Teslim Edildi	2026-03-16 20:35:17.934051	Usta 1	26031614	\N	\N		12000.00	Durum usta tarafından güncellendi	2026-03-17 21:32:07.090243	\N	\N	\N
9	9	Barkod okuyucu tetik mekanizması basmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031609	\N	\N	Depo ortamında kullanıldığı için genel temizlik de yapılacak.	0.00	\N	2026-03-16 21:48:59.371833	\N	\N	\N
2	2	Şarj soketi temassızlık yapıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031602	\N	\N	Cihazın yanında orijinal kılıf ve şarj aleti de teslim alındı.	4000.00	Durum usta tarafından güncellendi	2026-03-22 22:14:43.168867	\N	\N	\N
6	6	Menteşe kırık, fan aşırı gürültülü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031606	\N	\N	Firma yetkilisi: "Hız bizim için her şeyden önemli" dedi.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:49:15.077881	\N	\N	\N
8	8	Klavye üzerine kahve döküldü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031608	\N	\N	Klavye değişimi gerekirse fiyat onayı bekliyorlar.	0.00	Durum usta tarafından güncellendi	2026-03-17 21:32:12.009332	\N	\N	\N
25	15	Ggvv	İptal Edildi	2026-03-18 14:28:25.270281	Usta 1	26031805	\N	\N		0.00	\N	2026-03-18 18:24:20.59743	\N	\N	\N
29	19	Bozuk1	İptal Edildi	2026-03-18 15:21:49.440204	Usta 1	26031809	\N	\N		0.00	\N	2026-03-18 18:24:38.819044	8	\N	\N
4	4	Ses seviyesi çok düşük, cızırtılı.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031604	\N	\N	Cihazın garantisi devam ediyormuş, fatura fotokopisi içeride.	1000.00	Durum usta tarafından güncellendi	2026-03-17 21:26:22.235596	\N	\N	\N
20	16	camı yok	Teslim Edildi	2026-03-17 18:24:29.208061	Usta 1	26031701	\N	\N	kablolu	15000.00	Durum usta tarafından güncellendi	2026-03-17 18:49:47.085689	\N	\N	\N
5	5	Arka kamera odaklamıyor, bulanık.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031605	\N	\N	Müşteri usta ile bizzat görüşmek istiyor.	0.00	Durum usta tarafından güncellendi	2026-03-17 20:55:59.290685	\N	\N	\N
36	19	B9	İptal Edildi	2026-03-18 16:04:31.75451	Usta 1	26031816	\N	\N		0.00	\N	2026-03-18 18:22:49.730503	\N	8	\N
39	20	A20	İptal Edildi	2026-03-18 16:17:16.262383	Usta 1	26031819	\N	\N	A	0.00	\N	2026-03-18 18:22:36.802083	7	\N	\N
56	22	Bzhdhxj	İptal Edildi	2026-03-18 17:57:43.894544	Usta 1	26031836	\N	\N	Hdhxjc	0.00	\N	2026-03-18 18:20:57.556566	9	\N	\N
55	11	La4	İptal Edildi	2026-03-18 17:46:18.068006	Usta 1	26031835	\N	\N		0.00	\N	2026-03-18 18:21:00.643415	\N	6	\N
54	11	La2	İptal Edildi	2026-03-18 17:44:01.045641	Usta 1	26031834	\N	\N		0.00	\N	2026-03-18 18:21:03.683304	\N	6	\N
53	9	Ia1	İptal Edildi	2026-03-18 17:43:06.7438	Usta 1	26031833	\N	\N		0.00	\N	2026-03-18 18:21:55.33148	\N	4	\N
52	21	Jj	İptal Edildi	2026-03-18 17:37:31.186432	Seçilmedi	26031832	\N	\N	1	0.00	\N	2026-03-18 18:21:58.4	\N	9	\N
51	13	Kk	İptal Edildi	2026-03-18 17:12:07.141348	Usta 1	26031831	\N	\N		0.00	\N	2026-03-18 18:22:01.236347	\N	11	\N
50	14	T2	İptal Edildi	2026-03-18 16:55:00.997423	Usta 1	26031830	\N	\N		0.00	\N	2026-03-18 18:22:04.08923	\N	11	\N
49	14	Q1	İptal Edildi	2026-03-18 16:52:12.612412	Usta 1	26031829	\N	\N		0.00	\N	2026-03-18 18:22:06.757297	\N	11	\N
47	2	2	İptal Edildi	2026-03-18 16:42:49.61038	Usta 1	26031827	\N	\N		0.00	\N	2026-03-18 18:22:13.497812	1	\N	\N
46	2	1	İptal Edildi	2026-03-18 16:42:31.172981	Usta 1	26031826	\N	\N		0.00	\N	2026-03-18 18:22:16.559749	1	\N	\N
45	13	Z4	İptal Edildi	2026-03-18 16:39:54.839712	Usta 1	26031825	\N	\N		0.00	\N	2026-03-18 18:22:19.458825	\N	11	\N
44	16	Z2	İptal Edildi	2026-03-18 16:37:16.039815	Usta 1	26031824	\N	\N		0.00	\N	2026-03-18 18:22:22.439122	\N	11	\N
43	14	Z1	İptal Edildi	2026-03-18 16:36:03.87267	Usta 1	26031823	\N	\N		0.00	\N	2026-03-18 18:22:25.113869	\N	11	\N
42	11	C4	İptal Edildi	2026-03-18 16:30:56.57862	Usta 1	26031822	\N	\N		0.00	\N	2026-03-18 18:22:27.902063	\N	6	\N
41	11	C1	İptal Edildi	2026-03-18 16:28:30.203683	Usta 1	26031821	\N	\N		0.00	\N	2026-03-18 18:22:30.536348	\N	6	\N
40	2	A	İptal Edildi	2026-03-18 16:18:16.366707	Usta 1	26031820	\N	\N		0.00	\N	2026-03-18 18:22:34.152207	1	\N	\N
38	9	B12	İptal Edildi	2026-03-18 16:12:43.001157	Usta 1	26031818	\N	\N		0.00	\N	2026-03-18 18:22:40.415879	\N	4	\N
21	17	Bozuk calismiyor	İptal Edildi	2026-03-18 00:10:19.355918	Usta 1	26031801	\N	\N	Kablo	0.00	\N	2026-03-18 18:23:33.696245	\N	\N	\N
22	18	Ekran acilmiyor	İptal Edildi	2026-03-18 13:37:58.39378	Usta 1	26031802	\N	\N	Ekran karti	0.00	\N	2026-03-18 18:23:39.376803	\N	\N	\N
24	5	Jsjdjd	İptal Edildi	2026-03-18 14:24:02.632203	Usta 1	26031804	\N	\N		0.00	\N	2026-03-18 18:23:45.429715	\N	\N	\N
26	15	M1	İptal Edildi	2026-03-18 14:34:29.92715	Usta 1	26031806	\N	\N		0.00	\N	2026-03-18 18:23:50.266682	\N	\N	\N
28	19	Bozo	İptal Edildi	2026-03-18 15:17:14.214381	Usta 1	26031808	\N	\N		0.00	\N	2026-03-18 18:23:58.820262	\N	\N	\N
23	11	Hshshd	İptal Edildi	2026-03-18 14:08:19.458693	Usta 1	26031803	\N	\N		0.00	\N	2026-03-18 18:24:03.840532	\N	\N	\N
27	19	M2	İptal Edildi	2026-03-18 14:38:14.505594	Usta 1	26031807	\N	\N	Hhh	0.00	\N	2026-03-18 18:24:29.786994	\N	\N	\N
37	11	B10	İptal Edildi	2026-03-18 16:04:54.17375	Usta 1	26031817	\N	\N		0.00	\N	2026-03-22 22:12:05.053219	\N	6	\N
32	11	B4	İptal Edildi	2026-03-18 15:28:50.722963	Usta 1	26031812	\N	\N		0.00	\N	2026-03-18 18:24:43.878012	6	\N	\N
31	11	B3	İptal Edildi	2026-03-18 15:23:48.092818	Usta 1	26031811	\N	\N		0.00	\N	2026-03-18 18:24:49.41876	6	\N	\N
30	11	B2	İptal Edildi	2026-03-18 15:22:57.161396	Usta 1	26031810	\N	\N		0.00	\N	2026-03-18 18:24:56.200729	6	\N	\N
33	11	B5	İptal Edildi	2026-03-18 15:40:44.199463	Usta 1	26031813	\N	\N		0.00	\N	2026-03-18 18:25:15.941116	6	\N	\N
34	11	B6	İptal Edildi	2026-03-18 15:51:29.311264	Usta 1	26031814	\N	\N		0.00	\N	2026-03-22 22:12:07.993472	\N	6	\N
59	14	Yeni	İptal Edildi	2026-03-18 18:19:37.830142	Usta 1	26031839	\N	\N		0.00	\N	2026-03-18 18:20:45.037245	\N	11	\N
58	9	Yeni baslangic	İptal Edildi	2026-03-18 18:18:26.764166	Usta 1	26031838	\N	\N		0.00	\N	2026-03-18 18:20:50.278915	\N	4	\N
57	11	Hhhhh	İptal Edildi	2026-03-18 17:59:07.4454	Usta 1	26031837	\N	\N		0.00	\N	2026-03-18 18:20:54.058697	\N	6	\N
48	2	3	İptal Edildi	2026-03-18 16:43:05.445527	Usta 1	26031828	\N	\N		0.00	\N	2026-03-18 18:22:09.902852	1	\N	\N
35	11	B8	İptal Edildi	2026-03-18 15:57:15.088944	Usta 1	26031815	\N	\N		0.00	\N	2026-03-18 18:23:00.697265	\N	6	\N
98	16	Bbbh	Teslim Edildi	2026-03-24 14:23:23.601013	Usta 1	26032411	\N	\N		9999.00	Durum usta tarafından güncellendi	2026-03-24 14:24:13.366916	\N	11	\N
99	26	kgıuohg	Teslim Edildi	2026-03-24 14:26:37.67078	Usta 1	26032412	\N	\N		1.00	Durum usta tarafından güncellendi	2026-03-26 17:32:07.131985	11	\N	\N
76	17	çatlak	Teslim Edildi	2026-03-23 14:38:32.383194	Usta 1	26032302	\N	\N		2000.00	Durum usta tarafından güncellendi	2026-03-25 15:56:25.290784	\N	2	\N
77	5	Cam	Teslim Edildi	2026-03-23 15:37:53.123193	Usta 1	26032303	\N	\N		12000.00	Durum usta tarafından güncellendi	2026-03-25 15:56:02.047172	3	\N	\N
72	13	Bdbdbd	Teslim Edildi	2026-03-22 14:26:39.172362	Usta 1	26032201	\N	\N		0.00	\N	2026-03-22 15:33:59.721039	\N	11	\N
71	26	Ariza notu	Teslim Edildi	2026-03-20 17:47:10.037096	Usta 1	26032006	\N	\N	Musteri notu	1000.00	Durum usta tarafından güncellendi	2026-03-22 15:40:11.957419	11	\N	\N
87	29	Hsbdbd	Teslim Edildi	2026-03-23 18:56:25.715161	Usta 1	26032313	\N	\N	Hehedhdh	1500.00	\N	2026-03-24 00:13:38.12203	\N	8	\N
79	26	Gg	Teslim Edildi	2026-03-23 16:06:20.431917	Usta 1	26032305	\N	\N		2345.00	Usta 2345 TL fiyat verdi	2026-03-25 15:55:18.235076	11	\N	\N
74	14	Kasa	Teslim Edildi	2026-03-22 22:19:40.994277	Usta 1	26032204	\N	\N		10000.00	Durum usta tarafından güncellendi	2026-03-22 22:35:32.229585	\N	11	\N
70	25	Kasada catlak var	İptal Edildi	2026-03-20 17:18:41.338585	Usta 1	26032003	\N	\N	Ikinci el	0.00	\N	2026-03-22 22:11:25.943508	\N	12	\N
69	24	Kilif catlak	İptal Edildi	2026-03-20 17:17:31.868147	Seçilmedi	26032002	\N	\N	Kasa kirik	0.00	\N	2026-03-22 22:11:29.670277	11	\N	\N
68	23	Goruntu yok	İptal Edildi	2026-03-20 17:15:54.675709	Usta 1	26032001	\N	\N	Acele	0.00	\N	2026-03-22 22:11:32.881128	11	\N	\N
67	15	Hhh	İptal Edildi	2026-03-19 18:20:29.75046	Usta 1	26031910	\N	\N		0.00	\N	2026-03-22 22:11:36.120355	\N	8	\N
66	19	Bahsjsj	İptal Edildi	2026-03-19 18:19:10.410084	Usta 1	26031909	\N	\N		0.00	\N	2026-03-22 22:11:39.149528	\N	8	\N
65	14	Hhvv	İptal Edildi	2026-03-19 16:03:58.643812	Usta 1	26031906	\N	\N		0.00	\N	2026-03-22 22:11:42.238947	\N	11	\N
64	11	Bukbuk	İptal Edildi	2026-03-19 16:03:22.441856	Usta 1	26031905	\N	\N		0.00	\N	2026-03-22 22:11:45.33659	\N	6	\N
63	16	Son	İptal Edildi	2026-03-18 19:00:33.006645	Usta 1	26031845	\N	\N		5000.00	Usta 5000 TL fiyat verdi	2026-03-22 22:11:48.072459	\N	11	\N
62	13	Son	İptal Edildi	2026-03-18 18:59:26.395006	Usta 1	26031843	\N	\N		0.00	\N	2026-03-22 22:11:51.071633	\N	11	\N
61	14	Ll	İptal Edildi	2026-03-18 18:43:57.736524	Usta 1	26031841	\N	\N		0.00	\N	2026-03-22 22:11:56.636167	\N	11	\N
60	17	Ll	İptal Edildi	2026-03-18 18:42:24.434555	Usta 1	26031840	\N	\N		2500.00	Usta 2500 TL fiyat verdi	2026-03-22 22:12:00.223943	\N	2	\N
3	3	Sıvı teması sonrası cihaz açılmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031603	\N	\N	Acil işi olduğunu, bugün teslim alıp alamayacağını sordu.	0.00	Durum usta tarafından güncellendi	2026-03-22 22:14:40.188057	\N	\N	\N
90	32	Anten kirik	Teslim Edildi	2026-03-24 13:48:28.966822	Usta 1	26032403	\N	\N	Anten kablosu	3500.00	Durum usta tarafından güncellendi	2026-03-24 13:55:12.615665	3	\N	\N
84	27	GFHH	Teslim Edildi	2026-03-23 18:15:33.655772	Usta 1	26032310	\N	\N	HFG	5001.00	Durum usta tarafından güncellendi	2026-03-26 09:51:13.822153	11	\N	\N
86	11	Hdhdhd	Teslim Edildi	2026-03-23 18:52:36.868727	Usta 1	26032312	\N	\N		10000.00	Usta 10000 TL fiyat verdi	2026-03-24 00:16:19.522179	\N	6	\N
80	10	bbb	Teslim Edildi	2026-03-23 16:12:30.349202	Usta 1	26032306	\N	\N		50.00	Usta 50 TL fiyat verdi	2026-03-25 23:03:03.855427	\N	5	\N
93	8	Kass	Teslim Edildi	2026-03-24 14:03:06.469281	Usta 1	26032406	\N	\N		6666.00	Usta 6666 TL fiyat verdi	2026-03-24 14:04:17.610022	\N	3	\N
110	2	Hgg	Teslim Edildi	2026-03-25 12:13:26.931108	Usta 1	26032507	\N	\N		222.00	\N	2026-03-25 18:44:29.885111	1	\N	\N
111	9	Vvvh	Teslim Edildi	2026-03-25 18:45:21.94449	Usta 1	26032513	\N	\N		255.00	Usta 255 TL fiyat verdi	2026-03-25 18:52:27.909232	\N	4	\N
73	23	Cam	Teslim Edildi	2026-03-22 22:17:49.118601	Usta 1	26032202	\N	\N		5000.00	Durum usta tarafından güncellendi	2026-03-23 14:44:26.183022	11	\N	\N
75	13	bozuk	Teslim Edildi	2026-03-23 14:38:10.276368	Usta 1	26032301	\N	\N		0.00	\N	2026-03-23 15:23:31.457541	\N	11	\N
89	31	Garip	Teslim Edildi	2026-03-24 12:25:30.341299	Usta 1	26032402	\N	\N	Aman	5005.00	Durum usta tarafından güncellendi	2026-03-24 13:45:46.541196	\N	6	\N
83	21	Vhh	Teslim Edildi	2026-03-23 17:36:06.354867	Usta 1	26032309	\N	\N		100.00	Usta 100 TL fiyat verdi	2026-03-23 17:43:43.161302	\N	9	\N
94	22	Vhhh	Teslim Edildi	2026-03-24 14:09:45.779435	Usta 1	26032407	\N	\N		0.00	\N	2026-03-26 16:24:54.418983	9	\N	\N
88	30	Dikkat	Teslim Edildi	2026-03-24 00:31:15.30836	Usta 1	26032401	\N	\N	Aman ha	120000.00	Durum usta tarafından güncellendi	2026-03-24 11:45:00.988053	\N	11	\N
91	33	Cekmiyor	Teslim Edildi	2026-03-24 13:57:00.054789	Usta 1	26032404	\N	\N	Wifi	501.00	Durum usta tarafından güncellendi	2026-03-24 14:00:15.07362	6	\N	\N
85	28	FDGDFG	Teslim Edildi	2026-03-23 18:24:45.870833	Usta 1	26032311	\N	\N	DFGDFG	4000.00	Usta 4000 TL fiyat verdi	2026-03-24 12:10:54.429776	\N	12	\N
97	2	⁰babsbs	Teslim Edildi	2026-03-24 14:21:52.093888	Usta 1	26032410	\N	\N		123.00	Usta 123 TL fiyat verdi	2026-03-24 14:22:49.289003	1	\N	\N
95	1	Bhhh	İptal Edildi	2026-03-24 14:17:13.935534	Usta 1	26032408	\N	\N		0.00	Usta 0 TL fiyat verdi	2026-03-24 14:18:41.939219	1	\N	\N
92	10	Ucuvu 	Teslim Edildi	2026-03-24 14:01:08.471612	Usta 1	26032405	\N	\N		11.00	Usta 11 TL fiyat verdi	2026-03-24 14:02:11.82952	\N	5	\N
96	20	Hhhj	Teslim Edildi	2026-03-24 14:19:24.444099	Usta 1	26032409	\N	\N		888.00	\N	2026-03-24 14:21:20.931701	7	\N	\N
100	25	Bsbdb	Teslim Edildi	2026-03-24 14:32:54.582778	Usta 1	26032413	\N	\N		100.00	\N	2026-03-24 14:33:17.551674	\N	12	\N
102	26	Bbbh	Teslim Edildi	2026-03-24 14:37:51.859086	Usta 1	26032415	\N	\N		0.00	\N	2026-03-26 19:04:08.466206	11	\N	\N
101	11	Vbbnj	Teslim Edildi	2026-03-24 14:35:45.51377	Usta 1	26032414	\N	\N		501.00	\N	2026-03-26 18:51:49.624745	\N	6	\N
105	34	Whheehdh	Teslim Edildi	2026-03-24 18:06:56.514243	Usta 1	26032418	\N	\N	Hshdbdndnd	2509.00	Durum usta tarafından güncellendi	2026-03-26 23:56:34.949518	\N	10	\N
103	27	Gshshw	Teslim Edildi	2026-03-24 14:49:04.539631	Usta 1	26032416	\N	\N		9991.00	\N	2026-03-24 15:08:04.089493	11	\N	\N
104	2	Ghj	Teslim Edildi	2026-03-24 15:09:16.85568	Usta 1	26032417	\N	\N		1000.00	\N	2026-03-24 16:51:46.709259	1	\N	\N
106	9	Hsjehe	Teslim Edildi	2026-03-24 18:12:27.370158	Usta 1	26032419	\N	\N		700.00	\N	2026-03-24 18:21:38.297946	\N	4	\N
107	25	Hhcv	Teslim Edildi	2026-03-24 18:51:05.9353	Usta 1	26032420	\N	\N		105.00	\N	2026-03-24 18:52:04.41597	\N	12	\N
109	17	rrrer	Teslim Edildi	2026-03-24 21:21:09.0319	Usta 1	26032426	\N	\N		1508.00	Durum usta tarafından güncellendi	2026-03-24 21:46:32.416027	\N	2	\N
78	26	Ggg	Teslim Edildi	2026-03-23 16:05:23.659859	Usta 1	26032304	\N	\N		0.00	\N	2026-03-25 15:55:52.274112	11	\N	\N
81	22	Shshd	Teslim Edildi	2026-03-23 17:16:16.074085	Usta 1	26032307	\N	\N		1.00	Usta 1 TL fiyat verdi	2026-03-25 23:02:58.303687	9	\N	\N
82	9	ere	Teslim Edildi	2026-03-23 17:25:31.658712	Usta 1	26032308	\N	\N		1750.00	Usta 1750 TL fiyat verdi	2026-03-25 18:51:34.038894	\N	4	\N
108	27	ewerf	Teslim Edildi	2026-03-24 21:20:51.762693	Usta 1	26032425	\N	\N		250.00	Usta 250 TL fiyat verdi	2026-03-25 18:53:38.405458	11	\N	\N
122	38	Vvgh	Teslim Edildi	2026-03-31 14:22:07.378986	Usta 1	26033105	\N	\N		2500.00	\N	2026-03-31 14:23:33.824196	\N	13	\N
112	35	Musteri	Teslim Edildi	2026-03-25 18:55:11.149699	Usta 1	26032515	\N	\N	Gaz	550.00	Usta 550 TL fiyat verdi	2026-03-25 23:03:18.988105	6	\N	\N
135	39	Sjshdh	Teslim Edildi	2026-04-05 15:34:59.27562	Usta 1	26040505	\N	\N		35000.00	Durum usta tarafından güncellendi	2026-04-05 15:49:22.283339	\N	12	\N
123	14	N̈ejej	Teslim Edildi	2026-03-31 14:34:28.322235	Usta 1	26033107	\N	\N		7500.00	Usta 7500 TL fiyat verdi	2026-03-31 14:38:07.128692	\N	11	\N
113	14	B1	Teslim Edildi	2026-03-25 23:10:20.016853	Usta 1	26032516	\N	\N		555.00	\N	2026-03-26 10:15:06.954066	\N	11	\N
114	15	Nsndns	Teslim Edildi	2026-03-25 23:50:48.815293	Usta 1	26032518	\N	\N		101.00	\N	2026-03-26 10:15:41.829947	\N	8	\N
134	27	Bzhxhx	İptal Edildi	2026-04-05 15:34:43.02326	Usta 1	26040504	\N	\N		2000.00	Durum usta tarafından güncellendi	2026-04-07 16:03:35.043461	11	\N	\N
137	17	webbci	Teslim Edildi	2026-04-09 12:46:49.10286	Usta 1 (Kemal)	26040902	\N	\N	Kablo	7500.00	Durum usta tarafından güncellendi	2026-04-10 19:22:53.895829	\N	2	\N
115	9	D	Teslim Edildi	2026-03-26 13:22:18.889163	Usta 1	26032604	\N	\N		101.00	\N	2026-03-26 13:29:31.130054	\N	4	\N
127	39	Cam catlak	Teslim Edildi	2026-04-01 13:17:54.304814	Usta 1	26040103	\N	\N	Toner verdim	1555.00	Durum usta tarafından güncellendi	2026-04-04 09:54:54.03129	\N	12	\N
124	15	Rfgy	Teslim Edildi	2026-03-31 20:02:30.377617	Usta 1	26033108	\N	\N		12500.00	Durum usta tarafından güncellendi	2026-04-01 11:09:15.079068	\N	8	\N
116	14	Hshdh	Teslim Edildi	2026-03-26 13:30:50.812652	Usta 1	26032607	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-26 13:35:20.958675	\N	11	\N
128	9	Kilifi dar geldl	İptal Edildi	2026-04-04 11:31:03.165811	Usta 1	26040401	\N	\N		0.00	\N	2026-04-04 14:03:44.565809	\N	4	\N
119	37	Mavi ekran vae sikayet detagi	Teslim Edildi	2026-03-30 16:53:55.650863	Usta 1	26033001	\N	\N	Acele lazim	2750.00	Durum usta tarafından güncellendi	2026-03-30 18:09:10.894075	12	\N	\N
130	41	Bozuk c1	Teslim Edildi	2026-04-04 14:12:39.994697	Usta 1	26040404	\N	\N	Sarji yok	1250.00	Usta 1250 TL fiyat verdi	2026-04-04 14:31:51.196453	13	\N	\N
138	44	webb 2	İptal Edildi	2026-04-09 12:48:06.622849	Usta 1 (Kemal)	26040903	\N	\N	webb 2 iş kaydı	1003.00	Usta 1003 TL fiyat verdi	2026-04-10 19:40:34.132365	\N	2	firma vazgeçti
118	22	Hhh	Teslim Edildi	2026-03-26 16:59:13.210824	Usta 1	26032616	\N	\N		1500.00	Usta 1500 TL fiyat verdi	2026-03-31 13:53:24.27729	9	\N	\N
117	14	Vvv	Teslim Edildi	2026-03-26 16:58:54.523027	Usta 1	26032615	\N	\N		2750.00	\N	2026-03-31 13:55:17.139185	\N	11	\N
129	40	Bozuk ana	Teslim Edildi	2026-04-04 14:11:19.52684	Usta 1	26040403	\N	\N	Sarjli verildi	2550.00	Usta 2550 TL fiyat verdi	2026-04-04 14:42:16.855771	\N	14	\N
120	38	Sari ekran	Teslim Edildi	2026-03-31 13:56:58.707814	Usta 1	26033101	\N	\N	Kablo sizde	11500.00	\N	2026-03-31 13:59:14.096157	\N	13	\N
125	9	Cami kirik	Teslim Edildi	2026-04-01 11:10:03.904014	Usta 1	26040101	\N	\N		9999.00	Durum usta tarafından güncellendi	2026-04-01 12:14:02.686619	\N	4	\N
121	27	Ggg	Teslim Edildi	2026-03-31 14:11:53.300165	Usta 1	26033103	\N	\N		11000.00	Usta 11000 TL fiyat verdi	2026-03-31 14:16:57.804728	11	\N	\N
136	23	Bozuk	İptal Edildi	2026-04-09 11:19:32.406011	Usta 1	26040901	\N	\N		0.00	\N	2026-04-09 12:41:34.840182	11	\N	fiyatta anlaşılamadı
133	42	Ggg	İptal Edildi	2026-04-05 13:01:38.502861	Usta 1	26040503	\N	\N		2500.00	Durum usta tarafından güncellendi	2026-04-07 16:03:38.107917	\N	11	hırbo
132	42	Lamba bozuk	Teslim Edildi	2026-04-05 12:48:33.069416	Usta 1	26040502	\N	\N		3333.00	Durum usta tarafından güncellendi	2026-04-05 12:53:39.59147	\N	11	ölücü
126	26	Sari kapak	Teslim Edildi	2026-04-01 12:12:37.137153	Usta 1	26040102	\N	\N		5555.00	Durum usta tarafından güncellendi	2026-04-01 13:16:16.699565	11	\N	\N
131	42	Az tras ediyor	Teslim Edildi	2026-04-05 12:26:38.278493	Usta 1	26040501	\N	\N	Kesmiyor	7777.00	Durum usta tarafından güncellendi	2026-04-05 12:35:12.097295	\N	11	\N
147	51	sesi çıkmıyor yeni formdeneme	İptal Edildi	2026-04-12 23:28:25.555865	Usta 1 (Kemal)	26041220	\N	\N	sesi bozuk deneme	9999.00	Durum usta tarafından güncellendi	2026-04-13 14:44:58.077268	\N	2	\N
141	46	pil değişimi	Teslim Edildi	2026-04-10 18:18:17.700417	Usta 1 (Kemal)	26041002	\N	\N	pili sizde	16000.00	Durum usta tarafından güncellendi	2026-04-11 00:57:10.259024	12	\N	
143	47	b mobile muz 1 giriş 	Teslim Edildi	2026-04-12 15:09:05.263892	Usta 1 (Kemal)	26041201	\N	\N	servis 1	18000.00	Durum usta tarafından güncellendi	2026-04-13 15:42:05.594693	20	\N	\N
140	40	Cep	İptal Edildi	2026-04-10 18:16:48.042287	Usta 1	26041001	\N	\N		0.00	Durum usta tarafından güncellendi	2026-04-11 16:01:25.639644	\N	14	\N
139	45	webci 03	İptal Edildi	2026-04-09 12:53:48.809751	Usta 1 (Kemal)	26040904	\N	\N	webb kaydı3	0.00	\N	2026-04-11 16:05:40.369943	\N	15	\N
145	49	b web armut 	Teslim Edildi	2026-04-12 15:14:55.251362	Usta 1 (Kemal)	26041203	\N	\N	servis 3	12000.00	\N	2026-04-15 12:05:31.929951	22	\N	\N
142	25	web kaydı kırık	Teslim Edildi	2026-04-10 19:39:11.714842	Usta 1 (Kemal)	26041005	\N	\N	Ikinci el	2500.00	Durum usta tarafından güncellendi	2026-04-10 23:36:12.443025	\N	12	zor bir insan
144	48	f mobile muz 	Yeni Kayıt	2026-04-12 15:11:10.946848	Usta 1 (Kemal)	26041202	\N	\N	servis 2	0.00	\N	2026-04-12 15:11:10.946848	\N	21	\N
146	50	F web armut	Teslim Edildi	2026-04-12 15:17:53.223695	Usta 1	26041204	\N	\N	Servis 4	1200.00	\N	2026-04-13 19:42:02.752867	\N	23	\N
\.


--
-- Data for Name: shop_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shop_settings (id, key_name, value_text) FROM stdin;
2	default_tax_rate	20
3	relative_discount_rate	5
1	profit_margin	25
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password, role) FROM stdin;
1	admin@test.com	123456	admin
2	usta1@test.com	123456	usta
3	usta2@test.com	123456	usta
4	admin@kalandar.com	123456	admin
\.


--
-- Name: appointments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_id_seq', 144, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 22, true);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_id_seq', 51, true);


--
-- Name: envanter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.envanter_id_seq', 119, true);


--
-- Name: firms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.firms_id_seq', 24, true);


--
-- Name: kasa_islemleri_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.kasa_islemleri_id_seq', 344, true);


--
-- Name: material_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_requests_id_seq', 83, true);


--
-- Name: price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.price_history_id_seq', 39, true);


--
-- Name: service_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_notes_id_seq', 122, true);


--
-- Name: service_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_records_id_seq', 1, false);


--
-- Name: service_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_status_history_id_seq', 199, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 147, true);


--
-- Name: shop_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shop_settings_id_seq', 3, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1, false);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_servis_no_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_servis_no_key UNIQUE (servis_no);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: envanter envanter_barkod_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.envanter
    ADD CONSTRAINT envanter_barkod_key UNIQUE (barkod);


--
-- Name: envanter envanter_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.envanter
    ADD CONSTRAINT envanter_pkey PRIMARY KEY (id);


--
-- Name: firms firms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_pkey PRIMARY KEY (id);


--
-- Name: kasa_islemleri kasa_islemleri_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kasa_islemleri
    ADD CONSTRAINT kasa_islemleri_pkey PRIMARY KEY (id);


--
-- Name: material_requests material_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material_requests
    ADD CONSTRAINT material_requests_pkey PRIMARY KEY (id);


--
-- Name: price_history price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price_history
    ADD CONSTRAINT price_history_pkey PRIMARY KEY (id);


--
-- Name: service_notes service_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_notes
    ADD CONSTRAINT service_notes_pkey PRIMARY KEY (id);


--
-- Name: service_records service_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_records
    ADD CONSTRAINT service_records_pkey PRIMARY KEY (id);


--
-- Name: service_status_history service_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_status_history
    ADD CONSTRAINT service_status_history_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: services services_servis_no_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_servis_no_key UNIQUE (servis_no);


--
-- Name: shop_settings shop_settings_key_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_settings
    ADD CONSTRAINT shop_settings_key_name_key UNIQUE (key_name);


--
-- Name: shop_settings shop_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_settings
    ADD CONSTRAINT shop_settings_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_customers_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_customers_name ON public.customers USING btree (name);


--
-- Name: idx_devices_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_devices_customer_id ON public.devices USING btree (customer_id);


--
-- Name: idx_firms_firma_adi; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_firms_firma_adi ON public.firms USING btree (firma_adi);


--
-- Name: idx_services_device_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_services_device_id ON public.services USING btree (device_id);


--
-- Name: idx_services_servis_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_services_servis_no ON public.services USING btree (servis_no);


--
-- Name: envanter trg_price_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_price_change BEFORE UPDATE ON public.envanter FOR EACH ROW EXECUTE FUNCTION public.log_price_changes();


--
-- Name: appointments appointments_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: appointments appointments_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id);


--
-- Name: devices devices_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: price_history price_history_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price_history
    ADD CONSTRAINT price_history_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.envanter(id) ON DELETE CASCADE;


--
-- Name: service_notes service_notes_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_notes
    ADD CONSTRAINT service_notes_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: service_records service_records_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_records
    ADD CONSTRAINT service_records_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: service_records service_records_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_records
    ADD CONSTRAINT service_records_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: service_status_history service_status_history_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_status_history
    ADD CONSTRAINT service_status_history_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE CASCADE;


--
-- Name: services services_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: services services_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 4arXeXo1YEZqVyI60Jo12gVn1jl7UvbPaWTiDahkfoO1FmuMXZjknP0WgEaLhUP

