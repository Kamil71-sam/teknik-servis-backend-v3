--
-- PostgreSQL database dump
--

\restrict Ro4Tv1wLvnKIPiJ4EZZo9rLbvC13ZJ27eQG7hbJgva94xQgKGoYZ9w3KNGaEfr8

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
    usta_notu text
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
    miktar integer DEFAULT 0,
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
    firm_id integer
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

COPY public.appointments (id, customer_id, device_id, appointment_date, appointment_time, assigned_usta, issue_text, status, is_confirmed, created_at, servis_no, firm_id, price, usta_notu) FROM stdin;
6	1	\N	2026-03-28	15:00:00	Usta 1	Adres: Hshshs\nNot: Gagshs	İptal Edildi	f	2026-03-18 12:55:55.513405	26031802	\N	0.00	\N
7	1	\N	2026-03-31	18:00:00	Usta 1	Adres: Trabzon\nNot: Ekmek al	İptal Edildi	f	2026-03-18 12:57:24.363681	26031803	\N	0.00	\N
8	7	\N	2026-03-30	11:00:00	Usta 1	Adres: Eskisehir larnaka sk elif apt no10\nNot: Kirmizi ev	İptal Edildi	f	2026-03-18 13:06:06.535377	26031804	\N	0.00	\N
9	9	\N	2026-03-23	10:00:00	Usta 1	📍 ADRES: Yukari mah asagi sk ege apt no10\n\n📝 NOT: Kirmizi boyali ev	İptal Edildi	f	2026-03-18 13:16:19.624758	26031805	\N	0.00	\N
10	1	\N	2026-03-25	09:00:00	Usta 1	📍 ADRES: Kale male sale\n📝 NOT: Sari ev	İptal Edildi	f	2026-03-18 13:24:13.753927	26031806	\N	0.00	\N
11	9	\N	2026-03-28	19:00:00	Usta 1	📍 ADRES: Kayra apt etimesgut ankara\n📝 NOT: Yesil ev	İptal Edildi	f	2026-03-18 13:36:11.569422	26031807	\N	0.00	\N
12	1	\N	2026-03-19	23:00:00	Usta 1	📍 ADRES: Vsbshsh\n📝 NOT: Hsbdhdhd	İptal Edildi	f	2026-03-18 14:06:08.308113	26031808	\N	0.00	\N
13	1	\N	2026-03-26	11:00:00	Usta 1	📍 ADRES: Bshdh\n📝 NOT: Gshshdh	İptal Edildi	f	2026-03-18 14:24:35.356147	26031809	\N	0.00	\N
14	9	\N	2026-03-20	10:00:00	Usta 1	📍 ADRES: Varvar\n📝 NOT: R1	İptal Edildi	f	2026-03-18 14:40:12.391455	26031810	\N	0.00	\N
15	9	\N	2026-03-26	24:00:00	Usta 1	📍 ADRES: B7\n📝 NOT: B7	İptal Edildi	f	2026-03-18 15:56:36.438952	26031815	\N	0.00	\N
16	1	\N	2026-04-02	11:00:00	Usta 1	📍 ADRES: B8\n📝 NOT: B8	İptal Edildi	f	2026-03-18 16:04:04.720913	26031816	\N	0.00	\N
17	7	\N	2026-04-10	10:00:00	Usta 1	📍 ADRES: B11\n📝 NOT: B11	İptal Edildi	f	2026-03-18 16:05:37.557181	26031818	\N	0.00	\N
18	6	\N	2026-04-24	10:00:00	Usta 1	📍 ADRES: B13\n📝 NOT: B13	İptal Edildi	f	2026-03-18 16:13:39.689599	26031819	\N	0.00	\N
19	5	\N	2026-04-16	10:00:00	Usta 1	📍 ADRES: B14\n📝 NOT: B14	İptal Edildi	f	2026-03-18 16:16:08.098327	26031820	\N	0.00	\N
20	4	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: C2\n📝 NOT: C2	İptal Edildi	f	2026-03-18 16:29:20.240465	26031822	\N	0.00	\N
21	4	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: C3\n📝 NOT: C3	İptal Edildi	f	2026-03-18 16:30:32.535159	26031823	\N	0.00	\N
22	9	\N	2026-03-20	00:00:00	Usta 1	📍 ADRES: Z3\n📝 NOT: Z3	İptal Edildi	f	2026-03-18 16:38:23.657573	26031825	\N	0.00	\N
23	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Z5\n📝 NOT: Z5	İptal Edildi	f	2026-03-18 16:40:51.164206	26031826	\N	0.00	\N
24	4	\N	2026-03-20	11:11:00	Usta 1	📍 ADRES: 4\n📝 NOT: 4	İptal Edildi	f	2026-03-18 16:43:48.421333	26031829	\N	0.00	\N
25	7	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Q2\n📝 NOT: Q2	İptal Edildi	f	2026-03-18 16:52:49.34655	26031830	\N	0.00	\N
26	1	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: T1\n📝 NOT: T1	İptal Edildi	f	2026-03-18 16:54:20.874073	26031831	\N	0.00	\N
27	1	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: Y1\n📝 NOT: Y1	İptal Edildi	f	2026-03-18 17:32:05.567049	26031832	\N	0.00	\N
28	4	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: La3\n📝 NOT: La3	İptal Edildi	f	2026-03-18 17:45:38.002183	26031835	\N	0.00	\N
29	6	\N	2026-03-27	05:00:00	Usta 1	📍 ADRES: Hdhdbd\n📝 NOT: Hxhxhdh	İptal Edildi	f	2026-03-18 17:58:39.394776	26031837	\N	0.00	\N
30	9	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: Yeni\n📝 NOT: Yeni	İptal Edildi	f	2026-03-18 18:19:13.48068	26031839	\N	0.00	\N
31	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Ll\n📝 NOT: Ll	İptal Edildi	f	2026-03-18 18:43:17.522278	26031841	\N	0.00	\N
32	9	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Ll\n📝 NOT: Ll	İptal Edildi	f	2026-03-18 18:44:51.279754	26031842	\N	0.00	\N
33	9	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Son\n📝 NOT: Son	İptal Edildi	f	2026-03-18 19:00:01.825133	26031844	\N	0.00	\N
34	9	\N	2026-03-28	11:00:00	Usta 1	📍 ADRES: Hshdhd\n📝 NOT: Hsbshdh	İptal Edildi	f	2026-03-18 19:19:53.561712	26031846	\N	0.00	\N
35	6	\N	2026-03-27	10:00:00	Usta 1	📍 ADRES: Kayseri melikgazi\n🔧 CİHAZ: Masa ustu bilgisayar Hp Ts10/agc_7\n📝 NOT: Sicak kablo yok	İptal Edildi	f	2026-03-18 21:00:03.910399	26031847	\N	0.00	\N
36	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:03.097398	26031901	\N	0.00	\N
37	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:05.148869	26031902	\N	0.00	\N
38	9	\N	2026-04-24	14:23:00	Usta 1	📍 ADRES: pıjnnkşnl\n🔧 CİHAZ: jhbjbkjb huşuhhı.l kljhkjlnh\n📝 NOT: oıjeoıfjeıorjfel	İptal Edildi	f	2026-03-19 16:00:06.14883	26031903	\N	0.00	\N
39	9	\N	2026-03-29	10:00:00	Usta 1	📍 ADRES: Gsbsjs\n🔧 CİHAZ: Hshshdh Gshsbdbxb Hdhdjdjfjjfjfjdjdjdjd\n📝 NOT: Kac1	İptal Edildi	f	2026-03-19 16:01:49.077263	26031904	\N	0.00	\N
40	1	\N	2026-03-27	11:11:00	Usta 1	📍 ADRES: Ggggg\n🔧 CİHAZ: Gggg Gggg Tggg\n📝 NOT: Fddddddddee	İptal Edildi	f	2026-03-19 16:11:58.120491	26031907	\N	0.00	\N
41	1	\N	2026-03-28	11:00:00	Usta 1	📍 ADRES: Hshsj\n🔧 CİHAZ: Jshshs Jshsh Jsjdjdj\n📝 NOT: Bsbsvsh	İptal Edildi	f	2026-03-19 18:17:35.046828	26031908	\N	0.00	\N
42	\N	\N	2026-03-26	11:00:00	Usta 1	📍 ADRES: Bshshs\n🔧 CİHAZ: Hshshsh Hwhshdh Jshdhdh\n📝 NOT: Nsbsbdh	İptal Edildi	f	2026-03-19 18:21:26.722197	26031911	11	0.00	\N
43	3	\N	2026-03-27	11:00:00	Usta 1	📍 ADRES: Hhshsb\n🔧 CİHAZ: Hshhs Hshs Hshs\n📝 NOT: Snnshs	İptal Edildi	f	2026-03-19 18:24:53.194704	26031912	\N	0.00	\N
44	\N	\N	2026-03-27	11:00:00	Usta 1	📍 ADRES: Hwhehd\n🔧 CİHAZ: Hshdh Hshdh Jdhdj\n📝 NOT: Hshdh	İptal Edildi	f	2026-03-19 18:25:31.079071	26031913	6	0.00	\N
45	1	\N	2026-03-25	11:00:00	Usta 1	📍 ADRES: Bshshsj\n🔧 CİHAZ: Jshsh Hshsh Hshsh\n📝 NOT: Bsbsbshs	İptal Edildi	f	2026-03-19 18:58:57.98919	26031914	\N	0.00	\N
46	9	\N	2026-03-28	10:00:00	Usta 1	📍 ADRES: Vsgdgdhs\n🔧 CİHAZ: Hdhdhd Jdhdhdj Hdhdhdh\n📝 NOT: Bsbdbdhdj	İptal Edildi	f	2026-03-19 19:05:22.413085	26031915	\N	0.00	\N
47	1	\N	2026-03-21	10:00:00	Usta 1	📍 ADRES: Jejdjd\n🔧 CİHAZ: Hehdhdh Ndhdjd Jdjdjd\n📝 NOT: Jsjdjdj	İptal Edildi	f	2026-03-19 19:06:55.301721	26031916	\N	0.00	\N
48	\N	\N	2026-03-26	10:00:00	Usta 1	📍 ADRES: Bshshs\n🔧 CİHAZ: Jshshdh Jshshd Jdhdhdh\n📝 NOT: Bxbxbxh	İptal Edildi	f	2026-03-19 19:15:14.887685	26031917	4	0.00	\N
51	6	\N	2026-03-19	23:59:00	Usta 1	📍 ADRES: Bdjdnd\n🔧 CİHAZ: Hdhdjd Hdhdhf Hdhdhd\n📝 NOT: Bdbxbxbxb	Teslim Edildi	f	2026-03-19 23:58:19.907416	26031920	\N	5000.00	
49	\N	\N	2026-03-29	11:00:00	Usta 1	📍 ADRES: Bshdhdh\n🔧 CİHAZ: Hehdhdjfjf Hdhdhdhd Jdhdjdjdj\n📝 NOT: Hshdhdjd	İptal Edildi	f	2026-03-19 19:40:45.995698	26031918	3	0.00	\N
52	11	\N	2026-03-29	13:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Tel Sony Q1\n📝 NOT: Randevu 1	Teslim Edildi	f	2026-03-20 17:29:34.201166	26032004	\N	9000.00	Yes
53	\N	\N	2026-03-29	14:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Cep Sanyo 1q\n📝 NOT: Arda 2 olsun firma randuvu	Teslim Edildi	f	2026-03-20 17:30:48.449133	26032005	12	9999.00	Dokuz
54	\N	\N	2026-03-31	12:00:00	Usta 1	📍 ADRES: Cingen mah. Beytepe sk. Gul apt. Cincin / baglar/ ankara\n🔧 CİHAZ: Klavye Pirhana Zz10\n📝 NOT: Burasi not bolumu	Teslim Edildi	f	2026-03-20 18:35:30.263775	26032007	12	2500.00	Takip
50	\N	\N	2026-03-29	12:00:00	Usta 1	📍 ADRES: Jsjdjd\n🔧 CİHAZ: Hdhdh Jdhdhf Hdhdhd\n📝 NOT: Hshshdhndbshs	Teslim Edildi	f	2026-03-19 20:08:46.7787	26031919	2	2500.00	Tamam
55	\N	\N	2026-03-24	10:00:00	Usta 1	📍 ADRES: Ggg\n🔧 CİHAZ: T T T\n📝 NOT: Kirmizi	Teslim Edildi	f	2026-03-22 22:19:03.151624	26032203	1	40000.00	Hayda
56	\N	\N	2026-03-25	10:00:00	Usta 1	📍 ADRES: Hshdhd\n🔧 CİHAZ: Simens Hh H\n📝 NOT: Dbdhdhxh	Tamamlandı	f	2026-03-23 21:02:30.04677	26032314	11	8050.00	Gggg
57	11	\N	2026-03-29	13:00:00	Usta 1	📍 ADRES: Jehdhd\n🔧 CİHAZ: Bshshd Nshshsh Hshdhdh\n📝 NOT: Jebdhdbd	Tamamlandı	f	2026-03-23 21:55:18.40494	26032315	\N	1005.00	sıuwhdıu
58	\N	\N	2026-03-29	14:00:00	Usta 1	📍 ADRES: Hehehrjrjr\n🔧 CİHAZ: Jeueuruf Jrjrjrjf Jejdjfjf\n📝 NOT: Bshdhdhd	Teslim Edildi	f	2026-03-23 21:56:22.597304	26032316	12	1001.00	gece
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
11	ARDA BİR	05320000001	2026-03-20 16:04:39.106084	05320000001	ARDA@A.COM	KANAVA LOJ ERDEK BALIKESİR	bireysel
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
\.


--
-- Data for Name: envanter; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.envanter (id, barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, son_guncelleme, satis_fiyati, kar_orani_ozel, kdv_orani_ozel) FROM stdin;
1	GLCK-10001	Test Type-C Şarj Kablosu	Tüm Type-C Cihazlar	Dexim	15	120.50	2026-03-21 13:37:03.914552	0.00	\N	\N
4	GLCK-921359-3821	Labtop ekrani	5000 serisi	Hp	4	2500.00	2026-03-21 15:09:33.265433	0.00	\N	\N
7	GLCK-888956-6112	Kasa	Asus	Asus	1	4.00	2026-03-21 15:28:05.03987	0.00	\N	\N
8	GLCK-565660-5703	Cpu	1980 oncesi	Cikma	1	500.00	2026-03-21 15:36:50.164744	0.00	\N	\N
9	GLCK-484958-9000	Bdbdjd	Hsgshdh	Gsgdhddh	1646464	94845845.00	2026-03-21 16:08:22.256777	0.00	\N	\N
11	GLCK-276022-6118	Kopuk	Genel	Genel	1	1.00	2026-03-21 17:11:54.327991	0.00	\N	\N
12	GLCK-595837-6515	masa	Apple iPad Air 5	Exper	1	1000.00	2026-03-21 18:23:42.186424	0.00	\N	\N
13	GLCK-744376-2991	Yeni Ad degisti	Samsung Galaxy S23	Asil	1	123.00	2026-03-21 19:32:32.913569	0.00	\N	\N
14	GLCK-493578-1042	Saksak	Samsung Galaxy S23	Boss	10	525.00	2026-03-21 20:02:40.256584	0.00	\N	\N
15	GLCK-293761-1140	Gvvb	Samsung Galaxy S23	Son durum	4	20.00	2026-03-21 20:32:53.616149	0.00	\N	\N
16	GLCK-434594-4058	Gvvb	Samsung Galaxy S23	Son2	3	25.00	2026-03-21 20:34:18.801469	0.00	\N	\N
19	GLCK-443442-1577	Vsgsgd	Hshshdh	Hshdhdh	13	8.00	2026-03-21 21:07:39.054557	0.00	\N	\N
17	GLCK-273328-2512	san	Apple iPad Air 5		6	0.00	2026-03-21 22:33:11.195905	0.00	\N	\N
10	GLCK-546704-7568	Hardisk	Hdhdhf	Hdd	20	400.00	2026-03-22 19:54:53.070187	1250.00	\N	\N
23	0123456789	Cpu	13 pro	App	7	4000.00	2026-03-22 12:16:12.413941	0.00	\N	\N
26	1123456799	Ekran karti1	Tv1	Sony12	10	1500.00	2026-03-22 13:53:00.260226	0.00	\N	\N
6	1231231231232	Ekran ipad	11 ler	Apple	15	12000.00	2026-03-22 13:56:31.449979	0.00	\N	\N
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
8	Zirve Gıda Sanayi	Mert Zirve	05321000008	02628009010	2233445566	satis@zirve.com	Kullar, Kocaeli	2026-03-16 13:42:30.499229
9	Odak Reklam Ajansı	Selin Odak	05321000009	02629001020	7788990011	tasarim@odak.com	Çarşı, İzmit	2026-03-16 13:42:30.499229
10	Vatan Tekstil Fabrikası	İbrahim Vatan	05321000010	02620002030	3344556677	uretim@vatan.com	Dilovası, Kocaeli	2026-03-16 13:42:30.499229
6	Derin Denizcilik A.Ş.	Kaptan Yavuz	05321000006	\N	9988776655	kaptan@derin.com	Marina, Kocaeli	2026-03-16 13:42:30.499229
11	Kamil holding	AHMET KAMIL	0532	0532	222	g@g.com	Karayollari	2026-03-16 16:39:00.956743
12	ARDA İKİ	ARDA DARDA	05320000002	05320000002	001	ARDA2@A.COM	ELMALI MAH EŞME TRABZON	2026-03-20 16:06:12.41277
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
\.


--
-- Data for Name: price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.price_history (id, inventory_id, eski_alis, yeni_alis, eski_satis, yeni_satis, degisim_tarihi) FROM stdin;
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
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (id, device_id, issue_text, status, created_at, atanan_usta, servis_no, seri_no, garanti, musteri_notu, offer_price, expert_note, updated_at, customer_id, firm_id) FROM stdin;
1	1	Ekran kırık, görüntü tamamen yok.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031601	\N	\N	Müşteri cihazın daha önce hiç tamir görmediğini, titiz olduğunu belirtti.	0.00	Durum usta tarafından güncellendi	2026-03-17 20:57:05.912139	\N	\N
18	7	Girik	Teslim Edildi	2026-03-16 21:23:06.090923	Usta 1	26031618	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:37.845459	\N	\N
19	15	Isinma	Teslim Edildi	2026-03-16 21:36:57.534556	Usta 1	26031619	\N	\N	Isinma	2000.00	Durum usta tarafından güncellendi	2026-03-16 21:48:31.543982	\N	\N
17	12	Kirik	Teslim Edildi	2026-03-16 21:17:00.926633	Usta 1	26031617	\N	\N		1000.00	Durum usta tarafından güncellendi	2026-03-16 21:30:44.766313	\N	\N
16	11	Ekran	Teslim Edildi	2026-03-16 21:09:15.130386	Usta 1	26031616	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:51.424697	\N	\N
15	14	Ses yok	Teslim Edildi	2026-03-16 21:02:40.626057	Usta 1	26031615	\N	\N	Micro	3500.00	Durum usta tarafından güncellendi	2026-03-16 21:48:38.730277	\N	\N
13	13	Bozuk	Teslim Edildi	2026-03-16 16:40:05.494651	Usta 1	26031613	\N	\N	Kablo dahil geldi	2500.00	Durum usta tarafından güncellendi	2026-03-16 21:31:04.78975	\N	\N
12	12	Wi-Fi sürekli kopuyor, sinyal çok zayıf.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031612	\N	\N	Bağlantı sorunu sadece ofis içinde oluyormuş.	0.00	\N	2026-03-16 21:31:09.823985	\N	\N
7	7	Mavi ekran hatası (Kernel Panic).	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031607	\N	\N	Cihazın içinde önemli kurumsal veriler var, yedekleme istendi.	0.00	\N	2026-03-16 21:31:20.067573	\N	\N
10	10	Kağıt sıkıştırıyor, çıktı üzerinde lekeler var.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031610	\N	\N	Yazıcı drum ünitesi daha yeni değişmiş, dikkat edilsin.	0.00	\N	2026-03-16 17:36:06.095674	\N	\N
11	11	Batarya şişmiş, kasa esniyor.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031611	\N	\N	Ekranın sol üstünde hafif bir çatlak zaten vardı.	8200.00	Usta 8200 TL fiyat verdi	2026-03-16 21:48:51.527913	\N	\N
14	13	Bozuk	Teslim Edildi	2026-03-16 20:35:17.934051	Usta 1	26031614	\N	\N		12000.00	Durum usta tarafından güncellendi	2026-03-17 21:32:07.090243	\N	\N
9	9	Barkod okuyucu tetik mekanizması basmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031609	\N	\N	Depo ortamında kullanıldığı için genel temizlik de yapılacak.	0.00	\N	2026-03-16 21:48:59.371833	\N	\N
2	2	Şarj soketi temassızlık yapıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031602	\N	\N	Cihazın yanında orijinal kılıf ve şarj aleti de teslim alındı.	4000.00	Durum usta tarafından güncellendi	2026-03-22 22:14:43.168867	\N	\N
6	6	Menteşe kırık, fan aşırı gürültülü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031606	\N	\N	Firma yetkilisi: "Hız bizim için her şeyden önemli" dedi.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:49:15.077881	\N	\N
8	8	Klavye üzerine kahve döküldü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031608	\N	\N	Klavye değişimi gerekirse fiyat onayı bekliyorlar.	0.00	Durum usta tarafından güncellendi	2026-03-17 21:32:12.009332	\N	\N
25	15	Ggvv	İptal Edildi	2026-03-18 14:28:25.270281	Usta 1	26031805	\N	\N		0.00	\N	2026-03-18 18:24:20.59743	\N	\N
29	19	Bozuk1	İptal Edildi	2026-03-18 15:21:49.440204	Usta 1	26031809	\N	\N		0.00	\N	2026-03-18 18:24:38.819044	8	\N
4	4	Ses seviyesi çok düşük, cızırtılı.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031604	\N	\N	Cihazın garantisi devam ediyormuş, fatura fotokopisi içeride.	1000.00	Durum usta tarafından güncellendi	2026-03-17 21:26:22.235596	\N	\N
20	16	camı yok	Teslim Edildi	2026-03-17 18:24:29.208061	Usta 1	26031701	\N	\N	kablolu	15000.00	Durum usta tarafından güncellendi	2026-03-17 18:49:47.085689	\N	\N
5	5	Arka kamera odaklamıyor, bulanık.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031605	\N	\N	Müşteri usta ile bizzat görüşmek istiyor.	0.00	Durum usta tarafından güncellendi	2026-03-17 20:55:59.290685	\N	\N
36	19	B9	İptal Edildi	2026-03-18 16:04:31.75451	Usta 1	26031816	\N	\N		0.00	\N	2026-03-18 18:22:49.730503	\N	8
39	20	A20	İptal Edildi	2026-03-18 16:17:16.262383	Usta 1	26031819	\N	\N	A	0.00	\N	2026-03-18 18:22:36.802083	7	\N
56	22	Bzhdhxj	İptal Edildi	2026-03-18 17:57:43.894544	Usta 1	26031836	\N	\N	Hdhxjc	0.00	\N	2026-03-18 18:20:57.556566	9	\N
55	11	La4	İptal Edildi	2026-03-18 17:46:18.068006	Usta 1	26031835	\N	\N		0.00	\N	2026-03-18 18:21:00.643415	\N	6
54	11	La2	İptal Edildi	2026-03-18 17:44:01.045641	Usta 1	26031834	\N	\N		0.00	\N	2026-03-18 18:21:03.683304	\N	6
53	9	Ia1	İptal Edildi	2026-03-18 17:43:06.7438	Usta 1	26031833	\N	\N		0.00	\N	2026-03-18 18:21:55.33148	\N	4
52	21	Jj	İptal Edildi	2026-03-18 17:37:31.186432	Seçilmedi	26031832	\N	\N	1	0.00	\N	2026-03-18 18:21:58.4	\N	9
51	13	Kk	İptal Edildi	2026-03-18 17:12:07.141348	Usta 1	26031831	\N	\N		0.00	\N	2026-03-18 18:22:01.236347	\N	11
50	14	T2	İptal Edildi	2026-03-18 16:55:00.997423	Usta 1	26031830	\N	\N		0.00	\N	2026-03-18 18:22:04.08923	\N	11
49	14	Q1	İptal Edildi	2026-03-18 16:52:12.612412	Usta 1	26031829	\N	\N		0.00	\N	2026-03-18 18:22:06.757297	\N	11
47	2	2	İptal Edildi	2026-03-18 16:42:49.61038	Usta 1	26031827	\N	\N		0.00	\N	2026-03-18 18:22:13.497812	1	\N
46	2	1	İptal Edildi	2026-03-18 16:42:31.172981	Usta 1	26031826	\N	\N		0.00	\N	2026-03-18 18:22:16.559749	1	\N
45	13	Z4	İptal Edildi	2026-03-18 16:39:54.839712	Usta 1	26031825	\N	\N		0.00	\N	2026-03-18 18:22:19.458825	\N	11
44	16	Z2	İptal Edildi	2026-03-18 16:37:16.039815	Usta 1	26031824	\N	\N		0.00	\N	2026-03-18 18:22:22.439122	\N	11
43	14	Z1	İptal Edildi	2026-03-18 16:36:03.87267	Usta 1	26031823	\N	\N		0.00	\N	2026-03-18 18:22:25.113869	\N	11
42	11	C4	İptal Edildi	2026-03-18 16:30:56.57862	Usta 1	26031822	\N	\N		0.00	\N	2026-03-18 18:22:27.902063	\N	6
41	11	C1	İptal Edildi	2026-03-18 16:28:30.203683	Usta 1	26031821	\N	\N		0.00	\N	2026-03-18 18:22:30.536348	\N	6
40	2	A	İptal Edildi	2026-03-18 16:18:16.366707	Usta 1	26031820	\N	\N		0.00	\N	2026-03-18 18:22:34.152207	1	\N
38	9	B12	İptal Edildi	2026-03-18 16:12:43.001157	Usta 1	26031818	\N	\N		0.00	\N	2026-03-18 18:22:40.415879	\N	4
21	17	Bozuk calismiyor	İptal Edildi	2026-03-18 00:10:19.355918	Usta 1	26031801	\N	\N	Kablo	0.00	\N	2026-03-18 18:23:33.696245	\N	\N
22	18	Ekran acilmiyor	İptal Edildi	2026-03-18 13:37:58.39378	Usta 1	26031802	\N	\N	Ekran karti	0.00	\N	2026-03-18 18:23:39.376803	\N	\N
24	5	Jsjdjd	İptal Edildi	2026-03-18 14:24:02.632203	Usta 1	26031804	\N	\N		0.00	\N	2026-03-18 18:23:45.429715	\N	\N
26	15	M1	İptal Edildi	2026-03-18 14:34:29.92715	Usta 1	26031806	\N	\N		0.00	\N	2026-03-18 18:23:50.266682	\N	\N
28	19	Bozo	İptal Edildi	2026-03-18 15:17:14.214381	Usta 1	26031808	\N	\N		0.00	\N	2026-03-18 18:23:58.820262	\N	\N
23	11	Hshshd	İptal Edildi	2026-03-18 14:08:19.458693	Usta 1	26031803	\N	\N		0.00	\N	2026-03-18 18:24:03.840532	\N	\N
27	19	M2	İptal Edildi	2026-03-18 14:38:14.505594	Usta 1	26031807	\N	\N	Hhh	0.00	\N	2026-03-18 18:24:29.786994	\N	\N
37	11	B10	İptal Edildi	2026-03-18 16:04:54.17375	Usta 1	26031817	\N	\N		0.00	\N	2026-03-22 22:12:05.053219	\N	6
32	11	B4	İptal Edildi	2026-03-18 15:28:50.722963	Usta 1	26031812	\N	\N		0.00	\N	2026-03-18 18:24:43.878012	6	\N
31	11	B3	İptal Edildi	2026-03-18 15:23:48.092818	Usta 1	26031811	\N	\N		0.00	\N	2026-03-18 18:24:49.41876	6	\N
30	11	B2	İptal Edildi	2026-03-18 15:22:57.161396	Usta 1	26031810	\N	\N		0.00	\N	2026-03-18 18:24:56.200729	6	\N
33	11	B5	İptal Edildi	2026-03-18 15:40:44.199463	Usta 1	26031813	\N	\N		0.00	\N	2026-03-18 18:25:15.941116	6	\N
34	11	B6	İptal Edildi	2026-03-18 15:51:29.311264	Usta 1	26031814	\N	\N		0.00	\N	2026-03-22 22:12:07.993472	\N	6
59	14	Yeni	İptal Edildi	2026-03-18 18:19:37.830142	Usta 1	26031839	\N	\N		0.00	\N	2026-03-18 18:20:45.037245	\N	11
58	9	Yeni baslangic	İptal Edildi	2026-03-18 18:18:26.764166	Usta 1	26031838	\N	\N		0.00	\N	2026-03-18 18:20:50.278915	\N	4
57	11	Hhhhh	İptal Edildi	2026-03-18 17:59:07.4454	Usta 1	26031837	\N	\N		0.00	\N	2026-03-18 18:20:54.058697	\N	6
48	2	3	İptal Edildi	2026-03-18 16:43:05.445527	Usta 1	26031828	\N	\N		0.00	\N	2026-03-18 18:22:09.902852	1	\N
35	11	B8	İptal Edildi	2026-03-18 15:57:15.088944	Usta 1	26031815	\N	\N		0.00	\N	2026-03-18 18:23:00.697265	\N	6
98	16	Bbbh	Teslim Edildi	2026-03-24 14:23:23.601013	Usta 1	26032411	\N	\N		9999.00	Durum usta tarafından güncellendi	2026-03-24 14:24:13.366916	\N	11
84	27	GFHH	Teslim Edildi	2026-03-23 18:15:33.655772	Usta 1	26032310	\N	\N	HFG	5001.00	Durum usta tarafından güncellendi	2026-03-24 12:18:19.836109	11	\N
77	5	Cam	Teslim Edildi	2026-03-23 15:37:53.123193	Usta 1	26032303	\N	\N		12000.00	Durum usta tarafından güncellendi	2026-03-23 15:40:08.297453	3	\N
78	26	Ggg	Teslim Edildi	2026-03-23 16:05:23.659859	Usta 1	26032304	\N	\N		0.00	\N	2026-03-23 16:05:32.101792	11	\N
72	13	Bdbdbd	Teslim Edildi	2026-03-22 14:26:39.172362	Usta 1	26032201	\N	\N		0.00	\N	2026-03-22 15:33:59.721039	\N	11
71	26	Ariza notu	Teslim Edildi	2026-03-20 17:47:10.037096	Usta 1	26032006	\N	\N	Musteri notu	1000.00	Durum usta tarafından güncellendi	2026-03-22 15:40:11.957419	11	\N
87	29	Hsbdbd	Teslim Edildi	2026-03-23 18:56:25.715161	Usta 1	26032313	\N	\N	Hehedhdh	1500.00	\N	2026-03-24 00:13:38.12203	\N	8
79	26	Gg	Teslim Edildi	2026-03-23 16:06:20.431917	Usta 1	26032305	\N	\N		2345.00	Usta 2345 TL fiyat verdi	2026-03-23 16:09:18.222476	11	\N
74	14	Kasa	Teslim Edildi	2026-03-22 22:19:40.994277	Usta 1	26032204	\N	\N		10000.00	Durum usta tarafından güncellendi	2026-03-22 22:35:32.229585	\N	11
70	25	Kasada catlak var	İptal Edildi	2026-03-20 17:18:41.338585	Usta 1	26032003	\N	\N	Ikinci el	0.00	\N	2026-03-22 22:11:25.943508	\N	12
69	24	Kilif catlak	İptal Edildi	2026-03-20 17:17:31.868147	Seçilmedi	26032002	\N	\N	Kasa kirik	0.00	\N	2026-03-22 22:11:29.670277	11	\N
68	23	Goruntu yok	İptal Edildi	2026-03-20 17:15:54.675709	Usta 1	26032001	\N	\N	Acele	0.00	\N	2026-03-22 22:11:32.881128	11	\N
67	15	Hhh	İptal Edildi	2026-03-19 18:20:29.75046	Usta 1	26031910	\N	\N		0.00	\N	2026-03-22 22:11:36.120355	\N	8
66	19	Bahsjsj	İptal Edildi	2026-03-19 18:19:10.410084	Usta 1	26031909	\N	\N		0.00	\N	2026-03-22 22:11:39.149528	\N	8
65	14	Hhvv	İptal Edildi	2026-03-19 16:03:58.643812	Usta 1	26031906	\N	\N		0.00	\N	2026-03-22 22:11:42.238947	\N	11
64	11	Bukbuk	İptal Edildi	2026-03-19 16:03:22.441856	Usta 1	26031905	\N	\N		0.00	\N	2026-03-22 22:11:45.33659	\N	6
63	16	Son	İptal Edildi	2026-03-18 19:00:33.006645	Usta 1	26031845	\N	\N		5000.00	Usta 5000 TL fiyat verdi	2026-03-22 22:11:48.072459	\N	11
62	13	Son	İptal Edildi	2026-03-18 18:59:26.395006	Usta 1	26031843	\N	\N		0.00	\N	2026-03-22 22:11:51.071633	\N	11
61	14	Ll	İptal Edildi	2026-03-18 18:43:57.736524	Usta 1	26031841	\N	\N		0.00	\N	2026-03-22 22:11:56.636167	\N	11
60	17	Ll	İptal Edildi	2026-03-18 18:42:24.434555	Usta 1	26031840	\N	\N		2500.00	Usta 2500 TL fiyat verdi	2026-03-22 22:12:00.223943	\N	2
3	3	Sıvı teması sonrası cihaz açılmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031603	\N	\N	Acil işi olduğunu, bugün teslim alıp alamayacağını sordu.	0.00	Durum usta tarafından güncellendi	2026-03-22 22:14:40.188057	\N	\N
90	32	Anten kirik	Teslim Edildi	2026-03-24 13:48:28.966822	Usta 1	26032403	\N	\N	Anten kablosu	3500.00	Durum usta tarafından güncellendi	2026-03-24 13:55:12.615665	3	\N
80	10	bbb	Teslim Edildi	2026-03-23 16:12:30.349202	Usta 1	26032306	\N	\N		50.00	Usta 50 TL fiyat verdi	2026-03-23 16:13:36.977968	\N	5
86	11	Hdhdhd	Teslim Edildi	2026-03-23 18:52:36.868727	Usta 1	26032312	\N	\N		10000.00	Usta 10000 TL fiyat verdi	2026-03-24 00:16:19.522179	\N	6
81	22	Shshd	Teslim Edildi	2026-03-23 17:16:16.074085	Usta 1	26032307	\N	\N		1.00	Usta 1 TL fiyat verdi	2026-03-23 17:17:56.158809	9	\N
93	8	Kass	Teslim Edildi	2026-03-24 14:03:06.469281	Usta 1	26032406	\N	\N		6666.00	Usta 6666 TL fiyat verdi	2026-03-24 14:04:17.610022	\N	3
76	17	çatlak	Teslim Edildi	2026-03-23 14:38:32.383194	Usta 1	26032302	\N	\N		2000.00	Durum usta tarafından güncellendi	2026-03-23 14:43:34.8744	\N	2
82	9	ere	Teslim Edildi	2026-03-23 17:25:31.658712	Usta 1	26032308	\N	\N		1750.00	Usta 1750 TL fiyat verdi	2026-03-23 17:31:29.413156	\N	4
73	23	Cam	Teslim Edildi	2026-03-22 22:17:49.118601	Usta 1	26032202	\N	\N		5000.00	Durum usta tarafından güncellendi	2026-03-23 14:44:26.183022	11	\N
75	13	bozuk	Teslim Edildi	2026-03-23 14:38:10.276368	Usta 1	26032301	\N	\N		0.00	\N	2026-03-23 15:23:31.457541	\N	11
89	31	Garip	Teslim Edildi	2026-03-24 12:25:30.341299	Usta 1	26032402	\N	\N	Aman	5005.00	Durum usta tarafından güncellendi	2026-03-24 13:45:46.541196	\N	6
83	21	Vhh	Teslim Edildi	2026-03-23 17:36:06.354867	Usta 1	26032309	\N	\N		100.00	Usta 100 TL fiyat verdi	2026-03-23 17:43:43.161302	\N	9
94	22	Vhhh	Teslim Edildi	2026-03-24 14:09:45.779435	Usta 1	26032407	\N	\N		0.00	\N	2026-03-24 14:10:55.168357	9	\N
88	30	Dikkat	Teslim Edildi	2026-03-24 00:31:15.30836	Usta 1	26032401	\N	\N	Aman ha	120000.00	Durum usta tarafından güncellendi	2026-03-24 11:45:00.988053	\N	11
91	33	Cekmiyor	Teslim Edildi	2026-03-24 13:57:00.054789	Usta 1	26032404	\N	\N	Wifi	501.00	Durum usta tarafından güncellendi	2026-03-24 14:00:15.07362	6	\N
85	28	FDGDFG	Teslim Edildi	2026-03-23 18:24:45.870833	Usta 1	26032311	\N	\N	DFGDFG	4000.00	Usta 4000 TL fiyat verdi	2026-03-24 12:10:54.429776	\N	12
97	2	⁰babsbs	Teslim Edildi	2026-03-24 14:21:52.093888	Usta 1	26032410	\N	\N		123.00	Usta 123 TL fiyat verdi	2026-03-24 14:22:49.289003	1	\N
95	1	Bhhh	İptal Edildi	2026-03-24 14:17:13.935534	Usta 1	26032408	\N	\N		0.00	Usta 0 TL fiyat verdi	2026-03-24 14:18:41.939219	1	\N
92	10	Ucuvu 	Teslim Edildi	2026-03-24 14:01:08.471612	Usta 1	26032405	\N	\N		11.00	Usta 11 TL fiyat verdi	2026-03-24 14:02:11.82952	\N	5
96	20	Hhhj	Teslim Edildi	2026-03-24 14:19:24.444099	Usta 1	26032409	\N	\N		888.00	\N	2026-03-24 14:21:20.931701	7	\N
100	25	Bsbdb	Teslim Edildi	2026-03-24 14:32:54.582778	Usta 1	26032413	\N	\N		100.00	\N	2026-03-24 14:33:17.551674	\N	12
99	26	kgıuohg	Teslim Edildi	2026-03-24 14:26:37.67078	Usta 1	26032412	\N	\N		1.00	Durum usta tarafından güncellendi	2026-03-24 14:27:49.821575	11	\N
101	11	Vbbnj	Teslim Edildi	2026-03-24 14:35:45.51377	Usta 1	26032414	\N	\N		501.00	\N	2026-03-24 14:37:30.439148	\N	6
102	26	Bbbh	Teslim Edildi	2026-03-24 14:37:51.859086	Usta 1	26032415	\N	\N		0.00	\N	2026-03-24 14:41:13.801128	11	\N
103	27	Gshshw	Teslim Edildi	2026-03-24 14:49:04.539631	Usta 1	26032416	\N	\N		9991.00	\N	2026-03-24 15:08:04.089493	11	\N
104	2	Ghj	Teslim Edildi	2026-03-24 15:09:16.85568	Usta 1	26032417	\N	\N		1000.00	\N	2026-03-24 16:51:46.709259	1	\N
105	34	Whheehdh	Teslim Edildi	2026-03-24 18:06:56.514243	Usta 1	26032418	\N	\N	Hshdbdndnd	2509.00	Durum usta tarafından güncellendi	2026-03-24 18:09:15.068765	\N	10
106	9	Hsjehe	Teslim Edildi	2026-03-24 18:12:27.370158	Usta 1	26032419	\N	\N		700.00	\N	2026-03-24 18:21:38.297946	\N	4
107	25	Hhcv	Teslim Edildi	2026-03-24 18:51:05.9353	Usta 1	26032420	\N	\N		105.00	\N	2026-03-24 18:52:04.41597	\N	12
\.


--
-- Data for Name: shop_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shop_settings (id, key_name, value_text) FROM stdin;
1	profit_margin	20
2	default_tax_rate	20
3	relative_discount_rate	5
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password, role) FROM stdin;
1	admin@test.com	123456	admin
2	usta1@test.com	123456	usta
3	usta2@test.com	123456	usta
\.


--
-- Name: appointments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_id_seq', 58, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 11, true);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_id_seq', 34, true);


--
-- Name: envanter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.envanter_id_seq', 31, true);


--
-- Name: firms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.firms_id_seq', 12, true);


--
-- Name: kasa_islemleri_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.kasa_islemleri_id_seq', 66, true);


--
-- Name: material_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_requests_id_seq', 40, true);


--
-- Name: price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.price_history_id_seq', 1, false);


--
-- Name: service_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_notes_id_seq', 50, true);


--
-- Name: service_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_records_id_seq', 1, false);


--
-- Name: service_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_status_history_id_seq', 119, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 107, true);


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

\unrestrict Ro4Tv1wLvnKIPiJ4EZZo9rLbvC13ZJ27eQG7hbJgva94xQgKGoYZ9w3KNGaEfr8

