--
-- PostgreSQL database dump
--

\restrict l9ikdq4Fy3KFj7eCcQjhNiMaPtlCmYU0Eq8uOPksrapJQrKQOoyvYmOf9KY8R8a

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
\.


--
-- Data for Name: material_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.material_requests (id, service_id, usta_email, part_name, quantity, description, status, created_at) FROM stdin;
1	13	Usta_1	Hdd 1001	2	Cihaz: Efes - Not: Ssd111\n	Geldi	2026-03-16 16:43:07.563728
2	8	Usta_1	Ekran	1	Cihaz: Lenovo - Not: Avags	Beklemede	2026-03-16 17:07:55.665341
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
15	14	Usta_1	Ghh	1	Cihaz: Efes - Not: 	Beklemede	2026-03-16 20:48:01.23226
17	16	Usta_1	Vgghh	1	Cihaz: Apple - Not: Vvhh	Geldi	2026-03-16 21:13:16.818554
16	16	Usta_1	Dfffg	1	Cihaz: Apple - Not: Ggh	Geldi	2026-03-16 21:13:16.793069
19	18	Usta_1	Vvggj	1	Cihaz: Dell - Not: Bggg	Geldi	2026-03-16 21:24:26.719622
18	18	Usta_1	Fgvvg	1	Cihaz: Dell - Not: Bbvbj	Geldi	2026-03-16 21:24:26.690644
21	19	Usta_1	Bdhdhdh	1	Cihaz: Casped - Not: Hdhdhdh	Geldi	2026-03-16 21:38:27.489322
20	19	Usta_1	Gsgsg	1	Cihaz: Casped - Not: Hshdhdh	Geldi	2026-03-16 21:38:27.475052
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
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (id, device_id, issue_text, status, created_at, atanan_usta, servis_no, seri_no, garanti, musteri_notu, offer_price, expert_note, updated_at) FROM stdin;
5	5	Arka kamera odaklamıyor, bulanık.	Hazır	2026-03-16 13:49:25.33498	Usta 1	26031605	\N	\N	Müşteri usta ile bizzat görüşmek istiyor.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:48:12.051584
18	7	Girik	Teslim Edildi	2026-03-16 21:23:06.090923	Usta 1	26031618	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:37.845459
19	15	Isinma	Teslim Edildi	2026-03-16 21:36:57.534556	Usta 1	26031619	\N	\N	Isinma	2000.00	Durum usta tarafından güncellendi	2026-03-16 21:48:31.543982
17	12	Kirik	Teslim Edildi	2026-03-16 21:17:00.926633	Usta 1	26031617	\N	\N		1000.00	Durum usta tarafından güncellendi	2026-03-16 21:30:44.766313
16	11	Ekran	Teslim Edildi	2026-03-16 21:09:15.130386	Usta 1	26031616	\N	\N		1500.00	Durum usta tarafından güncellendi	2026-03-16 21:30:51.424697
15	14	Ses yok	Teslim Edildi	2026-03-16 21:02:40.626057	Usta 1	26031615	\N	\N	Micro	3500.00	Durum usta tarafından güncellendi	2026-03-16 21:48:38.730277
14	13	Bozuk	Teslim Edildi	2026-03-16 20:35:17.934051	Usta 1	26031614	\N	\N		12000.00	Durum usta tarafından güncellendi	2026-03-16 21:31:01.122185
13	13	Bozuk	Teslim Edildi	2026-03-16 16:40:05.494651	Usta 1	26031613	\N	\N	Kablo dahil geldi	2500.00	Durum usta tarafından güncellendi	2026-03-16 21:31:04.78975
4	4	Ses seviyesi çok düşük, cızırtılı.	Yeni Kayıt	2026-03-16 13:49:25.33498	Usta 1	26031604	\N	\N	Cihazın garantisi devam ediyormuş, fatura fotokopisi içeride.	0.00	\N	2026-03-16 16:41:52.766858
12	12	Wi-Fi sürekli kopuyor, sinyal çok zayıf.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031612	\N	\N	Bağlantı sorunu sadece ofis içinde oluyormuş.	0.00	\N	2026-03-16 21:31:09.823985
7	7	Mavi ekran hatası (Kernel Panic).	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031607	\N	\N	Cihazın içinde önemli kurumsal veriler var, yedekleme istendi.	0.00	\N	2026-03-16 21:31:20.067573
2	2	Şarj soketi temassızlık yapıyor.	Tamirde	2026-03-16 13:49:25.33498	Usta 1	26031602	\N	\N	Cihazın yanında orijinal kılıf ve şarj aleti de teslim alındı.	0.00	Durum usta tarafından güncellendi	2026-03-16 17:29:54.772952
10	10	Kağıt sıkıştırıyor, çıktı üzerinde lekeler var.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031610	\N	\N	Yazıcı drum ünitesi daha yeni değişmiş, dikkat edilsin.	0.00	\N	2026-03-16 17:36:06.095674
11	11	Batarya şişmiş, kasa esniyor.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031611	\N	\N	Ekranın sol üstünde hafif bir çatlak zaten vardı.	8200.00	Usta 8200 TL fiyat verdi	2026-03-16 21:48:51.527913
9	9	Barkod okuyucu tetik mekanizması basmıyor.	İptal Edildi	2026-03-16 13:49:25.33498	Usta 1	26031609	\N	\N	Depo ortamında kullanıldığı için genel temizlik de yapılacak.	0.00	\N	2026-03-16 21:48:59.371833
8	8	Klavye üzerine kahve döküldü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031608	\N	\N	Klavye değişimi gerekirse fiyat onayı bekliyorlar.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:49:11.228954
6	6	Menteşe kırık, fan aşırı gürültülü.	Teslim Edildi	2026-03-16 13:49:25.33498	Usta 1	26031606	\N	\N	Firma yetkilisi: "Hız bizim için her şeyden önemli" dedi.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:49:15.077881
3	3	Sıvı teması sonrası cihaz açılmıyor.	Tamirde	2026-03-16 13:49:25.33498	Usta 1	26031603	\N	\N	Acil işi olduğunu, bugün teslim alıp alamayacağını sordu.	0.00	\N	2026-03-16 13:49:25.33498
1	1	Ekran kırık, görüntü tamamen yok.	Hazır	2026-03-16 13:49:25.33498	Usta 1	26031601	\N	\N	Müşteri cihazın daha önce hiç tamir görmediğini, titiz olduğunu belirtti.	0.00	Durum usta tarafından güncellendi	2026-03-16 21:47:55.132278
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

SELECT pg_catalog.setval('public.customers_id_seq', 10, true);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_id_seq', 15, true);


--
-- Name: firms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.firms_id_seq', 11, true);


--
-- Name: material_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.material_requests_id_seq', 21, true);


--
-- Name: service_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_notes_id_seq', 25, true);


--
-- Name: service_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_records_id_seq', 1, false);


--
-- Name: service_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_status_history_id_seq', 47, true);


--
-- Name: services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_id_seq', 19, true);


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

\unrestrict l9ikdq4Fy3KFj7eCcQjhNiMaPtlCmYU0Eq8uOPksrapJQrKQOoyvYmOf9KY8R8a

