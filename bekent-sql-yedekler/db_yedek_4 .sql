--
-- PostgreSQL database dump
--

\restrict lVJgo0PnxmK64a0yHnZquHD0npJ1dfIS5X32xdISR0imw8MQJpjWVxaALTKgKcS

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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
-- Name: firms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.firms ALTER COLUMN id SET DEFAULT nextval('public.firms_id_seq'::regclass);


--
-- Name: material_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material_requests ALTER COLUMN id SET DEFAULT nextval('public.material_requests_id_seq'::regclass);


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
49	\N	\N	2026-03-29	11:00:00	Usta 1	📍 ADRES: Bshdhdh\n🔧 CİHAZ: Hehdhdjfjf Hdhdhdhd Jdhdjdjdj\n📝 NOT: Hshdhdjd	Beklemede	f	2026-03-19 19:40:45.995698	26031918	3	0.00	\N
50	\N	\N	2026-03-29	12:00:00	Usta 1	📍 ADRES: Jsjdjd\n🔧 CİHAZ: Hdhdh Jdhdhf Hdhdhd\n📝 NOT: Hshshdhndbshs	Beklemede	f	2026-03-19 20:08:46.7787	26031919	2	0.00	\N
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
51	6	\N	2026-03-19	23:59:00	Usta 1	📍 ADRES: Bdjdnd\n🔧 CİHAZ: Hdhdjd Hdhdhf Hdhdhd\n📝 NOT: Bdbxbxbxb	Tamamlandı	f	2026-03-19 23:58:19.907416	26031920	\N	5000.00	
52	11	\N	2026-03-29	13:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Tel Sony Q1\n📝 NOT: Randevu 1	Beklemede	f	2026-03-20 17:29:34.201166	26032004	\N	0.00	\N
53	\N	\N	2026-03-29	14:00:00	Usta 1	📍 ADRES: Gebze\n🔧 CİHAZ: Cep Sanyo 1q\n📝 NOT: Arda 2 olsun firma randuvu	Beklemede	f	2026-03-20 17:30:48.449133	26032005	12	0.00	\N
54	\N	\N	2026-03-31	12:00:00	Usta 1	📍 ADRES: Cingen mah. Beytepe sk. Gul apt. Cincin / baglar/ ankara\n🔧 CİHAZ: Klavye Pirhana Zz10\n📝 NOT: Burasi not bolumu	Beklemede	f	2026-03-20 18:35:30.263775	26032007	12	0.00	\N
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
-- Data for Name: material_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.material_requests (id, service_id, usta_email, part_name, quantity, description, status, created_at) FROM stdin;
1	13	Usta_1	Hdd 1001	2	Cihaz: Efes - Not: Ssd111\n	Geldi	2026-03-16 16:43:07.563728
7	2	Usta_1	Lcd	7	Cihaz: Apple - Not: Se1	Geldi	2026-03-16 17:30:32.150723
6	8	Usta_1	Ekran	5	Cihaz: Lenovo - Not: As1	Geldi	2026-03-16 17:28:44.664191
5	5	Usta_1	Lamba	5	Cihaz: Xiaomi - Not: Q1	Geldi	2026-03-16 17:20:59.003409
9	8	Usta_1	Renk	1	Cihaz: Lenovo - Not: 1	Geldi	2026-03-16 20:16:44.824839
8	8	Usta_1	Alo	1	Cihaz: Lenovo - Not: Qq	Geldi	2026-03-16 20:16:44.809442
4	1	Usta_1	Fado	4	Cihaz: Apple - Not: 111	Geldi	2026-03-16 17:19:44.511735
3	6	Usta_1	Sensor	2	Cihaz: HP - Not: Yu1	Geldi	2026-03-16 17:17:59.267289
12	14	Usta_1	Hdhdhd	1	Cihaz: Efes - Not: Jdhdhd	Geldi	2026-03-16 20:37:09.371411
11	14	Usta_1	Hdhdhd	1	Cihaz: Efes - Not: Bshdh	Geldi	2026-03-16 20:37:09.353066
10	14	Usta_1	Gagagz	1	Cihaz: Efes - Not: Bshshs	Geldi	2026-03-16 20:37:09.333621
14	14	Usta_1	Nsnejdj	1	Cihaz: Efes - Not: Nshdhdh	Geldi	2026-03-16 20:38:52.091893
13	14	Usta_1	Hdhdhw	1	Cihaz: Efes - Not: Hshdj	Geldi	2026-03-16 20:38:51.91476
17	16	Usta_1	Vgghh	1	Cihaz: Apple - Not: Vvhh	Geldi	2026-03-16 21:13:16.818554
16	16	Usta_1	Dfffg	1	Cihaz: Apple - Not: Ggh	Geldi	2026-03-16 21:13:16.793069
19	18	Usta_1	Vvggj	1	Cihaz: Dell - Not: Bggg	Geldi	2026-03-16 21:24:26.719622
18	18	Usta_1	Fgvvg	1	Cihaz: Dell - Not: Bbvbj	Geldi	2026-03-16 21:24:26.690644
21	19	Usta_1	Bdhdhdh	1	Cihaz: Casped - Not: Hdhdhdh	Geldi	2026-03-16 21:38:27.489322
20	19	Usta_1	Gsgsg	1	Cihaz: Casped - Not: Hshdhdh	Geldi	2026-03-16 21:38:27.475052
23	20	Usta_1	sarı metal	3	Cihaz: hundai - Not: kırmızı	Geldi	2026-03-17 18:48:29.220361
22	20	Usta_1	kart1	1	Cihaz: hundai - Not: ss40	Geldi	2026-03-17 18:48:29.208807
24	4	Usta_1	tfdhfgh	5	Cihaz: Samsung - Not: trrtyutry	Geldi	2026-03-17 20:57:35.065553
25	2	Usta_1	masa	1	Cihaz: Apple - Not: ssss	Beklemede	2026-03-17 21:21:10.616304
26	2	Usta_1	san	1	Cihaz: Apple - Not: sss	Beklemede	2026-03-17 21:21:10.628858
29	3	Usta_1	ghfgh	1	Cihaz: Samsung - Not: ghfgh	Geldi	2026-03-17 21:27:25.919552
28	3	Usta_1	gfhfgh	1	Cihaz: Samsung - Not: ghgfh	Geldi	2026-03-17 21:27:25.91088
27	3	Usta_1	ghjghjgh	1	Cihaz: Samsung - Not: ghgfh	Geldi	2026-03-17 21:27:25.900679
2	8	Usta_1	Ekran	1	Cihaz: Lenovo - Not: Avags	Geldi	2026-03-16 17:07:55.665341
15	14	Usta_1	Ghh	1	Cihaz: Efes - Not: 	Geldi	2026-03-16 20:48:01.23226
30	3	Usta_1	Gvvb	1	Cihaz: Samsung Galaxy S23 - Not: Ggh	Beklemede	2026-03-17 22:06:26.182606
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
37	11	B10	Onay Bekliyor	2026-03-18 16:04:54.17375	Usta 1	26031817	\N	\N		0.00	\N	2026-03-18 16:25:21.135044	\N	6
6	6	Menteşe kırık, fan aşırı gürültülü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031606	\N	\N	Firma yetkilisi: "Hız bizim için her şeyden önemli" dedi.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:49:15.077881	\N	\N
8	8	Klavye üzerine kahve döküldü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031608	\N	\N	Klavye değişimi gerekirse fiyat onayı bekliyorlar.	0.00	Durum usta tarafından güncellendi	2026-03-17 21:32:12.009332	\N	\N
25	15	Ggvv	İptal Edildi	2026-03-18 14:28:25.270281	Usta 1	26031805	\N	\N		0.00	\N	2026-03-18 18:24:20.59743	\N	\N
29	19	Bozuk1	İptal Edildi	2026-03-18 15:21:49.440204	Usta 1	26031809	\N	\N		0.00	\N	2026-03-18 18:24:38.819044	8	\N
4	4	Ses seviyesi çok düşük, cızırtılı.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031604	\N	\N	Cihazın garantisi devam ediyormuş, fatura fotokopisi içeride.	1000.00	Durum usta tarafından güncellendi	2026-03-17 21:26:22.235596	\N	\N
20	16	camı yok	Teslim Edildi	2026-03-17 18:24:29.208061	Usta 1	26031701	\N	\N	kablolu	15000.00	Durum usta tarafından güncellendi	2026-03-17 18:49:47.085689	\N	\N
5	5	Arka kamera odaklamıyor, bulanık.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031605	\N	\N	Müşteri usta ile bizzat görüşmek istiyor.	0.00	Durum usta tarafından güncellendi	2026-03-17 20:55:59.290685	\N	\N
34	11	B6	Yeni Kayıt	2026-03-18 15:51:29.311264	Usta 1	26031814	\N	\N		0.00	\N	2026-03-18 15:51:29.311264	\N	6
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
2	2	Şarj soketi temassızlık yapıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031602	\N	\N	Cihazın yanında orijinal kılıf ve şarj aleti de teslim alındı.	4000.00	Usta 4000 TL fiyat verdi	2026-03-18 18:24:34.057506	\N	\N
32	11	B4	İptal Edildi	2026-03-18 15:28:50.722963	Usta 1	26031812	\N	\N		0.00	\N	2026-03-18 18:24:43.878012	6	\N
31	11	B3	İptal Edildi	2026-03-18 15:23:48.092818	Usta 1	26031811	\N	\N		0.00	\N	2026-03-18 18:24:49.41876	6	\N
30	11	B2	İptal Edildi	2026-03-18 15:22:57.161396	Usta 1	26031810	\N	\N		0.00	\N	2026-03-18 18:24:56.200729	6	\N
33	11	B5	İptal Edildi	2026-03-18 15:40:44.199463	Usta 1	26031813	\N	\N		0.00	\N	2026-03-18 18:25:15.941116	6	\N
59	14	Yeni	İptal Edildi	2026-03-18 18:19:37.830142	Usta 1	26031839	\N	\N		0.00	\N	2026-03-18 18:20:45.037245	\N	11
58	9	Yeni baslangic	İptal Edildi	2026-03-18 18:18:26.764166	Usta 1	26031838	\N	\N		0.00	\N	2026-03-18 18:20:50.278915	\N	4
57	11	Hhhhh	İptal Edildi	2026-03-18 17:59:07.4454	Usta 1	26031837	\N	\N		0.00	\N	2026-03-18 18:20:54.058697	\N	6
48	2	3	İptal Edildi	2026-03-18 16:43:05.445527	Usta 1	26031828	\N	\N		0.00	\N	2026-03-18 18:22:09.902852	1	\N
35	11	B8	İptal Edildi	2026-03-18 15:57:15.088944	Usta 1	26031815	\N	\N		0.00	\N	2026-03-18 18:23:00.697265	\N	6
3	3	Sıvı teması sonrası cihaz açılmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031603	\N	\N	Acil işi olduğunu, bugün teslim alıp alamayacağını sordu.	0.00	Durum usta tarafından güncellendi	2026-03-18 18:24:12.714024	\N	\N
60	17	Ll	Yeni Kayıt	2026-03-18 18:42:24.434555	Usta 1	26031840	\N	\N		0.00	\N	2026-03-18 18:42:24.434555	\N	2
61	14	Ll	Yeni Kayıt	2026-03-18 18:43:57.736524	Usta 1	26031841	\N	\N		0.00	\N	2026-03-18 18:43:57.736524	\N	11
62	13	Son	Yeni Kayıt	2026-03-18 18:59:26.395006	Usta 1	26031843	\N	\N		0.00	\N	2026-03-18 18:59:26.395006	\N	11
64	11	Bukbuk	Yeni Kayıt	2026-03-19 16:03:22.441856	Usta 1	26031905	\N	\N		0.00	\N	2026-03-19 16:03:22.441856	\N	6
65	14	Hhvv	Yeni Kayıt	2026-03-19 16:03:58.643812	Usta 1	26031906	\N	\N		0.00	\N	2026-03-19 16:03:58.643812	\N	11
66	19	Bahsjsj	Yeni Kayıt	2026-03-19 18:19:10.410084	Usta 1	26031909	\N	\N		0.00	\N	2026-03-19 18:19:10.410084	\N	8
67	15	Hhh	Yeni Kayıt	2026-03-19 18:20:29.75046	Usta 1	26031910	\N	\N		0.00	\N	2026-03-19 18:20:29.75046	\N	8
68	23	Goruntu yok	Yeni Kayıt	2026-03-20 17:15:54.675709	Usta 1	26032001	\N	\N	Acele	0.00	\N	2026-03-20 17:15:54.675709	11	\N
69	24	Kilif catlak	Yeni Kayıt	2026-03-20 17:17:31.868147	Seçilmedi	26032002	\N	\N	Kasa kirik	0.00	\N	2026-03-20 17:17:31.868147	11	\N
70	25	Kasada catlak var	Yeni Kayıt	2026-03-20 17:18:41.338585	Usta 1	26032003	\N	\N	Ikinci el	0.00	\N	2026-03-20 17:18:41.338585	\N	12
63	16	Son	Onay Bekliyor	2026-03-18 19:00:33.006645	Usta 1	26031845	\N	\N		5000.00	Usta 5000 TL fiyat verdi	2026-03-20 23:24:32.510978	\N	11
71	26	Ariza notu	Tamirde	2026-03-20 17:47:10.037096	Usta 1	26032006	\N	\N	Musteri notu	1000.00	Durum usta tarafından güncellendi	2026-03-20 23:25:19.918495	11	\N
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

SELECT pg_catalog.setval('public.appointments_id_seq', 54, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 11, true);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_id_seq', 26, true);


--
-- Name: firms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.firms_id_seq', 12, true);


--
-- Name: material_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_requests_id_seq', 30, true);


--
-- Name: service_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_notes_id_seq', 33, true);


--
-- Name: service_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_records_id_seq', 1, false);


--
-- Name: service_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_status_history_id_seq', 63, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 71, true);


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
-- Name: firms firms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_pkey PRIMARY KEY (id);


--
-- Name: material_requests material_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.material_requests
    ADD CONSTRAINT material_requests_pkey PRIMARY KEY (id);


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

\unrestrict lVJgo0PnxmK64a0yHnZquHD0npJ1dfIS5X32xdISR0imw8MQJpjWVxaALTKgKcS

