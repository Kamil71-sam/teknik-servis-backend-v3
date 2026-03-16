--
-- PostgreSQL database dump
--

\restrict NKOj2p3JPJnHXZfELbujgCWl9XJ0gxMFAeybdeVvMR9fADxVxIydxs2PGkB46AR

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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
    updated_at timestamp without time zone DEFAULT now()
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
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, name, phone, created_at, fax, email, address, musteri_turu) FROM stdin;
200	Anadolu Sigorta (KURUMSAL)1	08501112233	2026-03-11 19:09:00.420417				bireysel
39	Ali veli	1	2026-03-15 14:55:46.955863	1	1l	1	bireysel
40	Adem	1	2026-03-15 15:37:20.742729	1	1l	1	bireysel
43	15	1	2026-03-15 20:01:40.081141	1	1	1	bireysel
44	16	1	2026-03-15 20:08:45.789857	1	1	1	bireysel
45	17	1	2026-03-15 20:40:26.090305	1	Q	1	bireysel
46	Kartal arda	666	2026-03-15 22:23:53.292032	666	Q@n.com	Katar	bireysel
2	Ayşe Fatma	05000000002	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
4	Can Yılmaz	05000000004	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
5	Zeynep Su	05000000005	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
6	Murat Ak	05000000006	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
7	Elif Nur	05000000007	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
8	Hakan Mert	05000000008	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
9	Selin Ece	05000000009	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
10	Burak Can	05000000010	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
11	Deniz Alp	05000000011	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
12	Gökhan Aras	05000000012	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
13	Seda Gül	05000000013	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
14	Onur Yiğit	05000000014	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
15	Aslı Şen	05000000015	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
16	Mert Gün	05000000016	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
17	Ebru Yüce	05000000017	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
18	Kaan Soy	05000000018	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
19	Pelin Can	05000000019	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
20	Yusuf Dağ	05000000020	2026-03-11 18:41:15.634355	\N	\N	\N	bireysel
21	Hhhhhhhh	5555	2026-03-11 19:32:38.127455	5555	Ggg@h.com	Ğgggggggggggg	bireysel
23	Vghbb	9899	2026-03-12 14:39:20.865194	8888	Cffgb	Gfggh	bireysel
24	Bsbxbz	97879	2026-03-12 15:02:06.715624	878788	Gsfshs	Vsvsh	bireysel
25	Zzzz	111	2026-03-13 17:59:56.7047	222	Q@n.com	Ask	bireysel
26	Qqqq	333	2026-03-13 18:31:22.3782	111	A@a.com	Aa	bireysel
27	QQQP	111	2026-03-13 19:25:08.081301	111	Q@Q.com	Q1	bireysel
28	Hshshx	979868	2026-03-13 19:40:00.743156	979767	Gsgsgd	Hshdhd	bireysel
29	Gxggxxgggx	686868	2026-03-13 20:17:34.19672	976868	Hxgxhgx	Hdhxhx	bireysel
33	4441	1	2026-03-13 22:41:12.617183	1	1	1	bireysel
32	333 yeni	3331	2026-03-13 22:28:50.517684	333	3331	3331\n	bireysel
30	Halil degis11	811	2026-03-13 20:26:44.003225	888	Ab	Gark	bireysel
37	Gsgxgd	976767	2026-03-15 10:58:49.731732	67676	Gsgsgs	Hshdhd	bireysel
1	Ali Veli1	05000000001	2026-03-11 18:41:15.634355				bireysel
31	Ahmet yeni11	9868686,	2026-03-13 22:19:47.046822	946868	1	1	bireysel
3	Mehmet Öz12	05000000003	2026-03-11 18:41:15.634355				bireysel
38	Q151	1	2026-03-15 11:18:27.418264	1	1	1	bireysel
501	Turkcell (KURUMSAL)	08500000001	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
502	Vodafone (KURUMSAL)	08500000002	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
503	Türk Telekom (KURUMSAL)	08500000003	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
504	Trendyol (KURUMSAL)	08500000004	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
505	Getir (KURUMSAL)	08500000005	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
506	Yemeksepeti (KURUMSAL)	08500000006	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
507	Hepsiburada (KURUMSAL)	08500000007	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
508	Ziraat Bankası (KURUMSAL)	08500000008	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
509	Garanti BBVA (KURUMSAL)	08500000009	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
510	Akbank (KURUMSAL)	08500000010	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
511	Koç Holding (KURUMSAL)	08500000011	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
512	Sabancı Holding (KURUMSAL)	08500000012	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
513	Eczacıbaşı (KURUMSAL)	08500000013	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
514	Thy Lojistik (KURUMSAL)	08500000014	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
515	Aras Kargo (KURUMSAL)	08500000015	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
516	Yurtiçi Kargo (KURUMSAL)	08500000016	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
517	MNG Kargo (KURUMSAL)	08500000017	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
518	Shell Türkiye (KURUMSAL)	08500000018	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
519	Opet (KURUMSAL)	08500000019	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
520	Petrol Ofisi (KURUMSAL)	08500000020	2026-03-11 19:16:37.52501	\N	\N	\N	bireysel
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.devices (id, customer_id, brand, model, serial_no, created_at, cihaz_turu, garanti_durumu, muster_notu, firm_id) FROM stdin;
1	1	Samsung	S24 Ultra	SN-2026-1	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
2	2	Xiaomi	Redmi Note 13	SN-2026-2	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
3	3	Huawei	P60 Pro	SN-2026-3	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
4	4	Oppo	Reno 10	SN-2026-4	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
5	5	Apple	iPhone 15	SN-2026-5	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
6	6	Samsung	S24 Ultra	SN-2026-6	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
7	7	Xiaomi	Redmi Note 13	SN-2026-7	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
8	8	Huawei	P60 Pro	SN-2026-8	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
9	9	Oppo	Reno 10	SN-2026-9	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
10	10	Apple	iPhone 15	SN-2026-10	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
11	11	Samsung	S24 Ultra	SN-2026-11	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
12	12	Xiaomi	Redmi Note 13	SN-2026-12	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
13	13	Huawei	P60 Pro	SN-2026-13	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
14	14	Oppo	Reno 10	SN-2026-14	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
15	15	Apple	iPhone 15	SN-2026-15	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
16	16	Samsung	S24 Ultra	SN-2026-16	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
17	17	Xiaomi	Redmi Note 13	SN-2026-17	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
18	18	Huawei	P60 Pro	SN-2026-18	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
19	19	Oppo	Reno 10	SN-2026-19	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
20	20	Apple	iPhone 15	SN-2026-20	2026-03-11 18:41:15.634355	Cep Telefonu	Garantili	Genel bakım ve kontrol.	\N
21	\N	Apple	MacBook Pro M3	SN-ANA-SIG-001	2026-03-11 18:57:06.222604	Dizüstü Bilgisayar	Kurumsal Garantili	Firma demirbaşıdır, acil onarım.	\N
22	\N	Anadolu Sigorta	MacBook Pro (Kurumsal)	SN-ANA-001	2026-03-11 19:00:44.101179	Bilgisayar	Garantili	Firma Kaydı: Anadolu Sigorta	\N
200	200	Apple	MacBook Pro	SN-ANA-200	2026-03-11 19:09:00.420417	Bilgisayar	Kurumsal Garantili	\N	\N
501	501	Kurumsal Marka	Model_F1	SN-FIRM-1	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
502	502	Kurumsal Marka	Model_F2	SN-FIRM-2	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
503	503	Kurumsal Marka	Model_F3	SN-FIRM-3	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
504	504	Kurumsal Marka	Model_F4	SN-FIRM-4	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
505	505	Kurumsal Marka	Model_F5	SN-FIRM-5	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
506	506	Kurumsal Marka	Model_F6	SN-FIRM-6	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
507	507	Kurumsal Marka	Model_F7	SN-FIRM-7	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
508	508	Kurumsal Marka	Model_F8	SN-FIRM-8	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
509	509	Kurumsal Marka	Model_F9	SN-FIRM-9	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
510	510	Kurumsal Marka	Model_F10	SN-FIRM-10	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
511	511	Kurumsal Marka	Model_F11	SN-FIRM-11	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
512	512	Kurumsal Marka	Model_F12	SN-FIRM-12	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
513	513	Kurumsal Marka	Model_F13	SN-FIRM-13	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
514	514	Kurumsal Marka	Model_F14	SN-FIRM-14	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
515	515	Kurumsal Marka	Model_F15	SN-FIRM-15	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
516	516	Kurumsal Marka	Model_F16	SN-FIRM-16	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
517	517	Kurumsal Marka	Model_F17	SN-FIRM-17	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
518	518	Kurumsal Marka	Model_F18	SN-FIRM-18	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
519	519	Kurumsal Marka	Model_F19	SN-FIRM-19	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
520	520	Kurumsal Marka	Model_F20	SN-FIRM-20	2026-03-11 19:16:37.52501	Donanım	Kurumsal Anlaşmalı	\N	\N
23	3	Hdhdh	Hehdh	Bdbdhd	2026-03-11 20:45:05.958361	Yazıcı	Var (Dükkan)	Bsbshd	\N
24	4	Gsgshs	Hshsh	Hshsh	2026-03-11 20:48:00.539679	Notebook	Var (Resmi)	Bsbdbd	\N
25	1	Bsbdbd	Jshdhd	Hshdhd	2026-03-11 20:53:53.031003	Notebook	Var (Dükkan)	Hshdhdjdhdhf	\N
26	502	Hsgsg	Hshxh	Jshzhx	2026-03-11 21:03:52.091177	Yazıcı	Var (Dükkan)	Hshdhdh	\N
27	515	Gsgsgs	Hshdhd	Hshdhdf	2026-03-11 21:04:58.999981	Tablet	Var (Dükkan)	Hshdhd	\N
28	15	Gzgzhx	Hzhxh	Hshdh	2026-03-11 21:07:35.34343	Tablet	Var (Dükkan)	Hshshd	\N
29	11	Hshdh	Bdhdhf	Hdhdhf	2026-03-11 21:17:45.327677	Masaüstü Bilgisayar	Var (Dükkan)	Ndjdjfjc	\N
30	11	Hsgsgdg	Hshdhd	Jshdhdu	2026-03-11 21:25:16.269951	Yazıcı	Var (Dükkan)	Hehdhdh	\N
31	504	Gsgsg	Hshdhd	Bshshdh	2026-03-11 21:28:56.22258	Masaüstü Bilgisayar	Var (Resmi)	Gagsgsgsh	\N
32	18	Hehdh	Hdhdh	Hehdhd	2026-03-11 21:32:01.660036	Yazıcı	Var (Dükkan)	Hehehdy	\N
33	3	Yeyeye	Hshshdg	Heheyd	2026-03-11 21:33:24.317553	Notebook	Var (Dükkan)	Gwgsgd	\N
34	200	Gzgzgx	Hshdhd	Hshdhdu	2026-03-11 21:38:04.9624	Tablet	Var (Resmi)	Hshdhdhd	\N
35	15	Hehehd	Hehdhd	Heheh	2026-03-11 21:38:50.932704	Masaüstü Bilgisayar	Yok		\N
36	12	Hsgsg	Hshsh	Hshshs	2026-03-11 21:44:11.528236	Tablet	Var (Resmi)	Hshshs	\N
37	1	Habsh	Jwhshs	Najshsj	2026-03-11 21:48:30.681894	Yazıcı	Var (Resmi)	Bahshs	\N
38	8	Bwhshsh	Hwhshs	Bsbsh	2026-03-11 21:53:13.106854	Yazıcı	Yok	Hwhwhe	\N
39	2	Heheh	Hehdh	Hehehd	2026-03-11 21:58:55.581274	Cep Telefonu	Var (Resmi)	Hehehdh	\N
40	1	Dfg	Hdhr	Hdhdhr	2026-03-11 22:00:14.784776	Cep Telefonu	Var (Resmi)	Jxjdjdh	\N
41	510	Jwheh	Nehdh	Behdh	2026-03-11 22:02:13.130743	Masaüstü Bilgisayar	Var (Dükkan)	Jshdh	\N
42	1	Hshshs	Bshsh	Jshdhdh	2026-03-11 22:09:59.378087	Masaüstü Bilgisayar	Var (Resmi)	Ndndbd	\N
43	4	Gsgzgz	Hsgsgd	Hshdhxj	2026-03-11 22:19:13.966698	Tablet	Var (Resmi)	Bsbxbxhx	\N
44	7	Hsbsbsh	Hshshxh	Nshsjdj	2026-03-11 22:20:41.325069	Masaüstü Bilgisayar	Var (Resmi)	Jehshdh	\N
45	1	Hshehs	Nshdhd	Bshdhdh	2026-03-11 22:23:02.265965	Cep Telefonu	Var (Resmi)	Hwhdhdh	\N
46	17	Sony	Aaa	1	2026-03-12 11:40:35.537952	Cep Telefonu	Var (Resmi)	Cam	\N
47	510	Hp	S	001	2026-03-12 11:41:37.828683	Masaüstü Bilgisayar	Yok	Hdd bozuk	\N
48	515	Gsgsg	Hshdh	Hshdh	2026-03-12 14:27:01.986014	Yazıcı	Var (Resmi)	Hsvsbd	\N
49	2	Gagag	Hahsh	Gshshs	2026-03-12 15:02:39.37674	Masaüstü Bilgisayar	Var (Resmi)	Gshshx	\N
50	7	Sony	A1	01	2026-03-13 18:02:39.620926	Notebook	Var (Resmi)	Hadi	\N
51	7	Suny	Iyi	Guzel	2026-03-13 18:04:56.315311	Cep Telefonu	Var (Dükkan)	Cancana	\N
52	510	H1	A1	1	2026-03-13 18:09:37.14565	Cep Telefonu	Var (Resmi)	A1	\N
53	1	A2	A2	A2	2026-03-13 18:10:25.471746	Masaüstü Bilgisayar	Var (Dükkan)	A2	\N
54	511	A3	A3	A3	2026-03-13 18:11:19.470007	Notebook	Yok	A3	\N
55	518	A4	A4	A4	2026-03-13 18:12:54.165215	Tablet	Yok	A4	\N
56	9	A5	A5	A5	2026-03-13 18:15:48.439247	Cep Telefonu	Var (Dükkan)	A5	\N
57	7	A6	A6	A6	2026-03-13 18:16:35.734106	Cep Telefonu	Var (Resmi)	A6	\N
58	26	A7	A7	A7	2026-03-13 18:32:00.854158	Tablet	Var (Dükkan)	A7	\N
59	7	A8	A8	A8	2026-03-13 18:32:51.891277	Masaüstü Bilgisayar	Yok	A8	\N
62	\N	Q1	Q1	Q1	2026-03-13 19:27:14.74564	Tablet	Var (Resmi)	Q1	9
63	26	Bzgsg	Hsgdg	Hsgdg	2026-03-13 19:28:12.940799	Masaüstü Bilgisayar	Yok	Vsgsg	\N
64	\N	Bahshs	Hsgzgz	Hshzhx	2026-03-13 19:42:07.148362	Cep Telefonu	Yok	Gshzhz	10
65	\N	Gsgshs	Hshdh	Hsgshdh	2026-03-13 20:22:44.076115	Cep Telefonu	Var (Resmi)	Hshdhdhd	12
66	30	App	A	1	2026-03-13 20:27:26.64328	Tablet	Var (Dükkan)	Halil	\N
67	\N	A	A	1	2026-03-13 20:28:35.65366	Masaüstü Bilgisayar	Var (Resmi)	A	513
68	\N	A	A	A	2026-03-13 20:29:39.578216	Masaüstü Bilgisayar	Var (Dükkan)	A	200
69	\N	A	A	1	2026-03-13 20:38:40.327669	Tablet	Var (Resmi)	A	1
70	\N	Jahah	Hshsh	Hshshs	2026-03-13 21:21:45.508942	Notebook	Var (Resmi)	Bshdhd	509
71	\N	Hshzhz	Bshzh	Nsbsh	2026-03-13 21:23:28.216363	Notebook	Var (Dükkan)	Sbzhz	510
72	\N	Jajsj	Hshsh	Hshsh	2026-03-13 21:24:42.404323	Notebook	Var (Resmi)	Hsheh	507
73	29	Fgghjk	Ggghh	Ggghh	2026-03-13 21:36:56.491557	Cep Telefonu	Var (Resmi)	Hhbjj	\N
74	\N	Ggg	Ggh	Hyh	2026-03-13 21:38:30.09362	Notebook	Var (Resmi)	Hhhj	505
75	\N	Gggh	Gtgh	Gfgg	2026-03-13 21:54:00.156077	Masaüstü Bilgisayar	Yok	Ggggb	100
76	31	1	1	1	2026-03-13 22:20:57.069887	Masaüstü Bilgisayar	Var (Dükkan)	1	\N
77	\N	2	2	2	2026-03-13 22:21:41.767513	Cep Telefonu	Var (Resmi)	2	13
78	32	333	333	333	2026-03-13 22:29:23.620537	Notebook	Var (Dükkan)	333	\N
79	33	1	1	1	2026-03-13 22:42:42.547425	Cep Telefonu	Var (Resmi)	1	\N
80	\N	2	2	2	2026-03-13 22:43:26.692645	Cep Telefonu	Var (Dükkan)	2	14
81	\N	Koc	Koc	1	2026-03-14 19:34:53.02362	Cep Telefonu	Var (Dükkan)	Ali koc	15
82	38	1	1	1	2026-03-15 11:19:42.095037	Cep Telefonu	Var (Resmi)	1	\N
83	\N	1	1	1	2026-03-15 11:20:58.560478	Cep Telefonu	Var (Dükkan)	1	19
84	1	Sam	Sam	Sam	2026-03-15 14:56:55.734969	Cep Telefonu	Var (Dükkan)	Sa	\N
87	\N	1	1	1	2026-03-15 20:06:57.654559	Cep Telefonu	Var (Resmi)	1	23
88	\N	1	1	1	2026-03-15 20:07:41.007972	Notebook	Var (Resmi)	1	23
89	44	1	1	1	2026-03-15 20:09:11.767526	Notebook	Var (Resmi)	1	\N
90	45	Whsgs	Bshdh	Hshdhd	2026-03-15 20:41:13.433588	Cep Telefonu	Var (Resmi)	Yessss	\N
91	45	Bshzj	Jzjx	Jsjsj	2026-03-15 20:41:56.636838	Notebook	Var (Dükkan)	Hhayde	\N
92	46	Apple	T17	001	2026-03-15 22:25:14.718042	Cep Telefonu	Var (Resmi)	Kablosu var acele	\N
93	\N	Sari	Yesil	001	2026-03-15 23:12:23.820072	Masaüstü Bilgisayar	Var (Resmi)	Fis	511
94	\N	Cas	Ca	1	2026-03-16 00:32:20.336688	Masaüstü Bilgisayar	Var (Resmi)	Cizik	515
95	\N	Casper	Aa	1	2026-03-16 09:51:25.501728	Masaüstü Bilgisayar	Var (Dükkan)	Bozuk	20
96	40	Can	Pas	1	2026-03-16 12:14:08.007381	Masaüstü Bilgisayar	Var (Resmi)	Fis	\N
\.


--
-- Data for Name: firms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.firms (id, firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres, created_at) FROM stdin;
1	Anadolu Sigorta Genel Merkez	Ahmet Yılmaz	08501112233	\N	\N	kurumsal@anadolu.com	\N	2026-03-11 18:57:06.222604
100	Anadolu Sigorta	Ahmet Bey	08501112233	\N	\N	\N	\N	2026-03-11 19:00:44.101179
200	Anadolu Sigorta	Ahmet Bey	08501112233	\N	\N	\N	\N	2026-03-11 19:09:00.420417
501	Turkcell	Yetkili_1	08500000001	\N	\N	\N	\N	2026-03-11 19:16:37.52501
502	Vodafone	Yetkili_2	08500000002	\N	\N	\N	\N	2026-03-11 19:16:37.52501
503	Türk Telekom	Yetkili_3	08500000003	\N	\N	\N	\N	2026-03-11 19:16:37.52501
504	Trendyol	Yetkili_4	08500000004	\N	\N	\N	\N	2026-03-11 19:16:37.52501
505	Getir	Yetkili_5	08500000005	\N	\N	\N	\N	2026-03-11 19:16:37.52501
506	Yemeksepeti	Yetkili_6	08500000006	\N	\N	\N	\N	2026-03-11 19:16:37.52501
507	Hepsiburada	Yetkili_7	08500000007	\N	\N	\N	\N	2026-03-11 19:16:37.52501
508	Ziraat Bankası	Yetkili_8	08500000008	\N	\N	\N	\N	2026-03-11 19:16:37.52501
509	Garanti BBVA	Yetkili_9	08500000009	\N	\N	\N	\N	2026-03-11 19:16:37.52501
510	Akbank	Yetkili_10	08500000010	\N	\N	\N	\N	2026-03-11 19:16:37.52501
511	Koç Holding	Yetkili_11	08500000011	\N	\N	\N	\N	2026-03-11 19:16:37.52501
512	Sabancı Holding	Yetkili_12	08500000012	\N	\N	\N	\N	2026-03-11 19:16:37.52501
513	Eczacıbaşı	Yetkili_13	08500000013	\N	\N	\N	\N	2026-03-11 19:16:37.52501
514	Thy Lojistik	Yetkili_14	08500000014	\N	\N	\N	\N	2026-03-11 19:16:37.52501
515	Aras Kargo	Yetkili_15	08500000015	\N	\N	\N	\N	2026-03-11 19:16:37.52501
516	Yurtiçi Kargo	Yetkili_16	08500000016	\N	\N	\N	\N	2026-03-11 19:16:37.52501
517	MNG Kargo	Yetkili_17	08500000017	\N	\N	\N	\N	2026-03-11 19:16:37.52501
518	Shell Türkiye	Yetkili_18	08500000018	\N	\N	\N	\N	2026-03-11 19:16:37.52501
519	Opet	Yetkili_19	08500000019	\N	\N	\N	\N	2026-03-11 19:16:37.52501
520	Petrol Ofisi	Yetkili_20	08500000020	\N	\N	\N	\N	2026-03-11 19:16:37.52501
2	Hahshzh	Hshzhx	979898	9798688	6467676	hshdhd	Hshdhdj	2026-03-11 19:29:12.486336
3	Yyyyyy	Uuuuuu	8888	8888	8888	ccc@jh.com	Hhĥhhhhhhhhhhh	2026-03-11 19:31:34.624779
4	Hshdj	Bshdhd	949495	949494	9484584	hsgsgd	Hshdh	2026-03-12 14:43:24.059585
5	Bsbxbx	Bzbxbx	989898	499497	949768	hshshx	Hshdh	2026-03-12 15:00:28.441684
6	Âaaaaaa	Bbbbbb	87878	878787	878787	vavsg	Bsbshx	2026-03-12 15:01:11.410228
7	Qqq	Kk	555	000	3	a@a.com	Aa	2026-03-13 18:00:31.900356
8	Qq1	A9	111	111	1	1@1.com	A9	2026-03-13 18:53:18.458139
9	QQQ1	Qqq1	111	111	1	qqq1@q.com	Qqq1	2026-03-13 19:26:01.17418
10	Qqqqqqs	Jshsh	67676	646768	6757688	gsgsg	Bshxhxh	2026-03-13 19:40:25.531366
11	Hshdhd	Hzhzhz	676868	675757	675875688	gdgdh	Gsgdyd	2026-03-13 20:17:55.178233
12	Qqquzel	Ahmet	1	1	1	2	Yahsi	2026-03-13 20:18:25.56322
14	442	2	2	2	2	2	2	2026-03-13 22:42:02.075956
13	2199	Yea	222	\N	2lll	2ppp	2jhh\n	2026-03-13 22:20:06.649597
15	Kockoc99	Ali1	2111	\N	3	a@n.com	Alk	2026-03-14 19:33:58.455849
18	Hshdhdh	Hshdh	9468688	9498998	545454	gsgsgs	Ushdjd	2026-03-15 10:59:08.536941
19	Q152	1	1	1	1	1	1	2026-03-15 11:18:55.32814
20	Badem	Aa	1	1	1	1	1	2026-03-15 15:37:42.973544
23	15	1	1,	1	1	1	1	2026-03-15 20:01:22.573679
24	17	1	1	1	1	1	1	2026-03-15 20:40:44.658193
\.


--
-- Data for Name: material_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.material_requests (id, service_id, usta_email, part_name, quantity, description, status, created_at) FROM stdin;
1	107	Usta_1	Ekran da ekran	1	Cihaz: Casper - Not: 0011	Geldi	2026-03-16 10:35:18.47626
2	107	Usta_1	Hddd 500	1	Cihaz: Casper - Not: Minik	Geldi	2026-03-16 11:00:29.875708
3	108	Usta_1	Fis ucu	1	Cihaz: Can - Not: Kazim	Geldi	2026-03-16 12:17:12.611274
4	109	Usta_1	Fis ucu	1	Cihaz: Casper - Not: B01	Geldi	2026-03-16 12:43:52.671624
\.


--
-- Data for Name: service_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_notes (id, service_id, note_text, created_at) FROM stdin;
1	108	Kemal Müdür: Fis ucu teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 12:31:57.889027
2	109	Kemal Müdür: Fis ucu teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.	2026-03-16 12:44:15.791478
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
1	102	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-15 21:42:55.046202
2	104	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 2500 TL fiyat verdi	2026-03-15 22:25:53.349701
3	104	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:01:39.811561
4	104	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:02:16.397789
5	90	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:07:24.374143
6	102	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:07:28.90802
7	102	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:07:34.740505
8	90	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:08:44.322913
9	105	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 10000 TL fiyat verdi	2026-03-15 23:14:16.963018
10	105	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:15:42.518346
11	105	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:16:59.079551
12	105	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:18:03.309765
13	105	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-15 23:18:40.640562
14	106	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-16 00:51:28.986945
15	107	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1500 TL fiyat verdi	2026-03-16 09:52:10.964967
16	107	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 09:53:23.549375
17	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 09:53:27.252586
18	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 09:53:32.489559
19	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 09:54:10.708034
20	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 09:54:50.010808
21	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:15:01.206131
22	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:15:08.428636
23	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:15:12.849685
24	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:15:20.672894
25	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:23:17.974963
26	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:23:21.11536
27	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:23:25.010893
28	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:34:45.300871
29	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:34:49.411464
30	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:34:51.434837
31	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:34:54.047157
32	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 10:59:54.154931
33	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 11:00:05.119328
34	107	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 11:08:12.900502
35	107	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 11:08:15.479674
36	107	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 11:08:17.879877
37	108	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 5000 TL fiyat verdi	2026-03-16 12:15:16.565413
38	108	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:16:33.452654
39	108	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:16:39.714632
40	108	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:16:42.357237
41	108	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:16:45.627964
42	108	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:32:26.538277
43	108	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:32:29.376399
44	108	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:32:33.278103
45	109	Yeni Kayıt	Onay Bekliyor	Usta_1	Usta 1750 TL fiyat verdi	2026-03-16 12:35:24.90945
46	109	Onaylandı	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:43:10.849325
47	109	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:43:16.266697
48	109	Parça Bekliyor	Tamirde	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:43:19.251706
49	109	Tamirde	Parça Bekliyor	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:43:22.976183
50	109	Tamirde	Hazır	Usta_1	Durum usta tarafından güncellendi	2026-03-16 12:45:04.515727
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (id, device_id, issue_text, status, created_at, atanan_usta, servis_no, seri_no, garanti, musteri_notu, offer_price, expert_note, updated_at) FROM stdin;
1	1		İptal Edildi	2026-03-11 14:00:00	Usta 1	26031101	\N	\N		0.00	\N	2026-03-15 19:58:56.036905
104	92	Ekran bozuk	Teslim Edildi	2026-03-15 22:25:29.800646	Usta 1	26031507	\N	\N	Kablosu var acele	2500.00	Durum usta tarafından güncellendi	2026-03-15 23:06:24.195956
108	96	Ucu yok	Teslim Edildi	2026-03-16 12:14:21.718913	Usta 1	26031603	\N	\N	Fis	5000.00	Durum usta tarafından güncellendi	2026-03-16 12:33:12.332366
107	95	Kirik	Teslim Edildi	2026-03-16 09:51:34.969866	Usta 1	26031602	\N	\N	Bozuk	1500.00	Durum usta tarafından güncellendi	2026-03-16 11:08:50.342433
2	2	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031102	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
3	3	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031103	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
4	4	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031104	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
5	5	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031105	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
6	6	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031106	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
7	7	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031107	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
8	8	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031108	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
9	9	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031109	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
10	10	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031110	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
11	11	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031111	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
12	12	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031112	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
13	13	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031113	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
14	14	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031114	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
15	15	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031115	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
16	16	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031116	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
87	77		Teslim Edildi	2026-03-13 22:21:50.298883	Usta 1	26031329	\N	\N		0.00	\N	2026-03-15 19:48:16.189944
88	78		Teslim Edildi	2026-03-13 22:29:31.001293	Usta 1	26031330	\N	\N		0.00	\N	2026-03-15 19:26:08.864461
89	78		İptal Edildi	2026-03-13 22:37:03.306467	Usta 1	26031331	\N	\N		0.00	\N	2026-03-15 19:26:34.397735
90	79		İptal Edildi	2026-03-13 22:42:52.934396	Usta 1	26031332	\N	\N		0.00	Durum usta tarafından güncellendi	2026-03-15 23:09:08.182896
105	93	Kirik bozuk	Teslim Edildi	2026-03-15 23:12:34.050554	Usta 1	26031508	\N	\N	Fisi bozuk	10000.00	Durum usta tarafından güncellendi	2026-03-15 23:19:33.954555
109	95	Cami catlak	İptal Edildi	2026-03-16 12:34:35.684594	Usta 1	26031604	\N	\N		1750.00	Durum usta tarafından güncellendi	2026-03-16 12:45:30.610602
59	50	Vvar var	KabulEdildi	2026-03-13 18:02:56.197961	Usta 1	26031301	\N	\N	\N	0.00	\N	2026-03-13 18:02:56.197961
60	51	Camini silin	KabulEdildi	2026-03-13 18:05:13.770423	Usta 1	26031302	\N	\N	\N	0.00	\N	2026-03-13 18:05:13.770423
61	52	Q1	KabulEdildi	2026-03-13 18:09:45.668953	Usta 1	26031303	\N	\N	\N	0.00	\N	2026-03-13 18:09:45.668953
63	54	A3	KabulEdildi	2026-03-13 18:11:29.467923	Usta 1	26031305	\N	\N	\N	0.00	\N	2026-03-13 18:11:29.467923
64	55	A4	KabulEdildi	2026-03-13 18:13:01.132703	Usta 1	26031306	\N	\N	\N	0.00	\N	2026-03-13 18:13:01.132703
65	56	A5	KabulEdildi	2026-03-13 18:15:57.113278	Usta 1	26031307	\N	\N	\N	0.00	\N	2026-03-13 18:15:57.113278
66	57	A6	KabulEdildi	2026-03-13 18:16:42.882654	Usta 3	26031308	\N	\N	\N	0.00	\N	2026-03-13 18:16:42.882654
67	58	A7	KabulEdildi	2026-03-13 18:32:10.29366	Usta 1	26031309	\N	\N	\N	0.00	\N	2026-03-13 18:32:10.29366
68	59	A8	KabulEdildi	2026-03-13 18:33:00.837654	Usta 1	26031310	\N	\N	\N	0.00	\N	2026-03-13 18:33:00.837654
69	62	Q1	KabulEdildi	2026-03-13 19:27:22.733514	Seçilmedi	26031311	\N	\N	\N	0.00	\N	2026-03-13 19:27:22.733514
70	63	Vsgzgz	KabulEdildi	2026-03-13 19:28:20.980526	Usta 2	26031312	\N	\N	\N	0.00	\N	2026-03-13 19:28:20.980526
71	509	Bahzh	KabulEdildi	2026-03-13 19:30:13.163063	Usta 2	26031313	\N	\N	\N	0.00	\N	2026-03-13 19:30:13.163063
72	64	Gsgxgx	KabulEdildi	2026-03-13 19:42:16.173892	Usta 2	26031314	\N	\N	\N	0.00	\N	2026-03-13 19:42:16.173892
73	65	Hshdhdh	KabulEdildi	2026-03-13 20:22:56.685764	Usta 1	26031315	\N	\N	\N	0.00	\N	2026-03-13 20:22:56.685764
75	67	A	KabulEdildi	2026-03-13 20:28:43.069405	Usta 3	26031317	\N	\N	\N	0.00	\N	2026-03-13 20:28:43.069405
76	68	A	KabulEdildi	2026-03-13 20:29:45.69341	Usta 3	26031318	\N	\N	\N	0.00	\N	2026-03-13 20:29:45.69341
77	69	A	KabulEdildi	2026-03-13 20:38:48.510753	Usta 3	26031319	\N	\N	\N	0.00	\N	2026-03-13 20:38:48.510753
78	70	Cgjjj	KabulEdildi	2026-03-13 21:21:52.291856	Usta 1	26031320	\N	\N	\N	0.00	\N	2026-03-13 21:21:52.291856
79	71	Cvb	KabulEdildi	2026-03-13 21:23:34.131344	Usta 1	26031321	\N	\N	\N	0.00	\N	2026-03-13 21:23:34.131344
80	72	Ghhjj	KabulEdildi	2026-03-13 21:24:48.225161	Usta 3	26031322	\N	\N	\N	0.00	\N	2026-03-13 21:24:48.225161
81	71	Gggg	KabulEdildi	2026-03-13 21:36:02.503454	Usta 2	26031323	\N	\N	\N	0.00	\N	2026-03-13 21:36:02.503454
82	73	Cvhj	KabulEdildi	2026-03-13 21:37:08.407501	Usta 2	26031324	\N	\N	\N	0.00	\N	2026-03-13 21:37:08.407501
84	74	Ggbh	KabulEdildi	2026-03-13 21:38:35.852904	Usta 3	26031326	\N	\N	\N	0.00	\N	2026-03-13 21:38:35.852904
85	75	Fvggb	KabulEdildi	2026-03-13 21:54:09.789877	Usta 2	26031327	\N	\N	\N	0.00	\N	2026-03-13 21:54:09.789877
86	76	1	KabulEdildi	2026-03-13 22:21:05.726462	Usta 1	26031328	\N	\N	\N	0.00	\N	2026-03-13 22:21:05.726462
62	53	3 deneme	PASIF / ARSIV	2026-03-13 18:10:33.425717	Usta 2	26031304	\N	\N	Oynama	0.00	\N	2026-03-15 14:32:14.66938
74	66	Halil	Pasif	2026-03-13 20:27:36.275506	Usta 1	26031316	\N	\N	\N	0.00	\N	2026-03-13 20:27:36.275506
83	53	Ggg	Pasif	2026-03-13 21:37:36.686538	Usta 2	26031325	\N	\N	\N	0.00	\N	2026-03-13 21:37:36.686538
92	81	Koc	Pasif	2026-03-14 19:35:02.554266	Usta 1	26031401	\N	\N	\N	0.00	\N	2026-03-14 19:35:02.554266
54	45	Vegsgege	Pasif	2026-03-11 22:23:19.232511	Usta 2	26031149	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
95	84	Yeşss	Pasif	2026-03-15 14:57:07.308122	Usta2	26031501	\N	\N	Simdi haydi111	0.00	\N	2026-03-15 15:08:37.694883
17	17	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031117	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
102	90		Teslim Edildi	2026-03-15 20:41:27.981876	Usta 1	26031505	\N	\N		0.00	Durum usta tarafından güncellendi	2026-03-15 23:08:07.11259
99	87	1	KabulEdildi	2026-03-15 20:07:04.546103	Usta 2	26031502	\N	\N	\N	0.00	\N	2026-03-15 20:07:04.546103
100	88	Gagsgs	KabulEdildi	2026-03-15 20:07:51.77116	Usta 1	26031503	\N	\N	\N	0.00	\N	2026-03-15 20:07:51.77116
101	89	2	KabulEdildi	2026-03-15 20:09:19.986352	Usta 2	26031504	\N	\N	Alo	0.00	\N	2026-03-15 20:27:17.433097
103	91	Hjhj	Yeni Kayıt	2026-03-15 20:42:03.356306	Usta 2	26031506	\N	\N	Hhayde	0.00	\N	2026-03-15 20:42:03.356306
18	18	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031118	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
19	19	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_2	26031119	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
20	20	Arıza tespiti yapılıyor.	Yeni Kayıt	2026-03-11 14:00:00	Usta_1	26031120	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
21	21	Klavye ve batarya değişimi.	Yeni Kayıt	2026-03-11 18:57:06.222604	Usta_1	26031121	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
22	22	Anadolu Sigorta - Kurumsal Bakım	Yeni Kayıt	2026-03-11 19:00:44.101179	Usta_1	26031122	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
23	200	Firma cihazı - Yıllık Bakım	Yeni Kayıt	2026-03-11 19:09:00.420417	Usta_1	26031123	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
24	501	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031124	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
25	502	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031125	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
26	503	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031126	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
27	504	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031127	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
28	505	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031128	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
29	506	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031129	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
30	507	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031130	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
31	508	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031131	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
32	509	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031132	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
33	510	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031133	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
34	511	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031134	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
35	512	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031135	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
36	513	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031136	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
37	514	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031137	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
38	515	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031138	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
39	516	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031139	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
40	517	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031140	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
41	518	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031141	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
42	519	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031142	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
43	520	Periyodik Bakım	Yeni Kayıt	2026-03-11 19:16:37.52501	Usta_Kurumsal	26031143	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
49	24	Hshdhdhdh	Yeni Kayıt	2026-03-11 20:48:09.247977	Usta 3	26031144	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
50	26	Bzhzgdg	Yeni Kayıt	2026-03-11 21:04:15.368006	Usta 2	26031145	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
51	27	Hehdhdh	Yeni Kayıt	2026-03-11 21:05:07.371379	Usta 3	26031146	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
52	28	Hagwgege	Yeni Kayıt	2026-03-11 21:07:44.670227	Usta 2	26031147	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
53	44	Hehehdh	Yeni Kayıt	2026-03-11 22:20:49.162119	Usta 2	26031148	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
55	46	Cami kirik	Yeni Kayıt	2026-03-12 11:40:51.136696	Usta 1	26031201	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
56	47	Arizali bozuk	Yeni Kayıt	2026-03-12 11:41:55.460301	Usta 2	26031202	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
57	48	Vsbdhdh	Yeni Kayıt	2026-03-12 14:27:09.991246	Usta 2	26031203	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
58	49	Gshdhdh	Yeni Kayıt	2026-03-12 15:02:47.06529	Usta 2	26031204	\N	\N	\N	0.00	\N	2026-03-13 09:52:05.756038
106	94	Bozuk	Onay Bekliyor	2026-03-16 00:32:35.022035	Usta 1	26031601	\N	\N	Cizik	1500.00	Usta 1500 TL fiyat verdi	2026-03-16 00:51:28.985186
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
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 46, true);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_id_seq', 96, true);


--
-- Name: firms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.firms_id_seq', 24, true);


--
-- Name: material_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_requests_id_seq', 4, true);


--
-- Name: service_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_notes_id_seq', 2, true);


--
-- Name: service_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_records_id_seq', 1, false);


--
-- Name: service_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_status_history_id_seq', 50, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 109, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1, false);


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
-- Name: services trg_daily_servis_no; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_daily_servis_no BEFORE INSERT ON public.services FOR EACH ROW EXECUTE FUNCTION public.generate_daily_servis_no();


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
-- Name: services services_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id);


--
-- PostgreSQL database dump complete
--

\unrestrict NKOj2p3JPJnHXZfELbujgCWl9XJ0gxMFAeybdeVvMR9fADxVxIydxs2PGkB46AR

