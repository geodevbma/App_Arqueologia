import { useEffect, useMemo, useRef, useState } from "react";
import type React from "react";
import type { FormEvent } from "react";
import L from "leaflet";
import { AnimatePresence, motion } from "framer-motion";
import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  Activity,
  Archive,
  BadgeCheck,
  Building2,
  Camera,
  ChevronDown,
  Cloud,
  Download,
  FileSpreadsheet,
  FileText,
  FormInput,
  Loader2,
  Lock,
  LogOut,
  MapPinned,
  PanelLeftClose,
  PanelLeftOpen,
  Plus,
  Route,
  Save,
  Search,
  ShieldCheck,
  Smartphone,
  Sparkles,
  UploadCloud,
  UsersRound,
} from "lucide-react";
import {
  api,
  exportUrl,
  getCollections,
  getForms,
  getMe,
  getProjects,
  getSections,
  getUsers,
  getWorkPoints,
  login,
  useAuthStore,
} from "./lib/api";
import type { Collection, DynamicForm, FormField, Project, User } from "./lib/api";
import brandtLogo from "./assets/brandt-logo.png";

type View = "dashboard" | "users" | "projects" | "forms" | "collections" | "map";
type Toast = { id: number; title: string; detail: string; tone: "success" | "error" | "info" };

const navItems: Array<{ id: View; label: string; icon: typeof Activity }> = [
  { id: "dashboard", label: "Dashboard", icon: Activity },
  { id: "users", label: "Usuarios", icon: UsersRound },
  { id: "projects", label: "Projetos", icon: Building2 },
  { id: "forms", label: "Formularios", icon: FormInput },
  { id: "collections", label: "Coletas", icon: Archive },
  { id: "map", label: "Mapa", icon: MapPinned },
];

const fieldTypes = [
  "text",
  "textarea",
  "number",
  "date",
  "time",
  "datetime",
  "boolean",
  "select",
  "multiselect",
  "photo",
  "coordinate",
];

const formatRole: Record<string, string> = {
  admin: "Administrador",
  coordinator: "Coordenador",
  archaeologist: "Arqueologo",
  viewer: "Visualizador",
};

const brand = {
  green: "#0A7354",
  accent: "#339A51",
  blue: "#0F486E",
  dark: "#061411",
  soft: "#F4F8F6",
  border: "#DCE7E3",
  text: "#10231F",
  muted: "#64756F",
};

function cx(...classes: Array<string | false | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function getAnswer(collection: Collection, key: string) {
  return collection.answers.find((answer) => answer.field_key === key)?.answer_value;
}

function initials(name: string) {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function collectionTone(status: string, syncStatus?: string): "green" | "amber" | "red" | "neutral" {
  if (status === "reviewed" || syncStatus === "synced") return "green";
  if (["sync_error", "conflict"].includes(status) || ["sync_error", "conflict"].includes(syncStatus ?? "")) return "red";
  if (["pending_sync", "syncing", "draft"].includes(status) || syncStatus === "pending_sync") return "amber";
  return "neutral";
}

function BrandtLogo({ compact = false, inverted = false }: { compact?: boolean; inverted?: boolean }) {
  return (
    <div className={cx("flex items-center gap-3", compact ? "min-w-0" : "")}>
      <img
        src={brandtLogo}
        alt="Brandt"
        className={cx(compact ? "h-12 w-auto" : "h-16 w-auto", inverted && "brightness-0 invert")}
      />
    </div>
  );
}

function Button({
  children,
  tone = "primary",
  type = "button",
  onClick,
  disabled,
}: {
  children: React.ReactNode;
  tone?: "primary" | "secondary" | "ghost" | "danger";
  type?: "button" | "submit";
  onClick?: () => void;
  disabled?: boolean;
}) {
  const toneClass = {
    primary: "brand-gradient text-white shadow-lg shadow-emerald-900/20 hover:shadow-xl",
    secondary: "bg-[#EAF4F0] text-[#0A7354] hover:bg-[#D9ECE5]",
    ghost: "bg-white/70 text-[#10231F] ring-1 ring-[#DCE7E3] hover:bg-white",
    danger: "bg-[#A23A35] text-white hover:bg-[#842d2a]",
  }[tone];
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={cx(
        "premium-btn inline-flex min-h-10 max-w-full items-center justify-center gap-2 rounded-lg px-4 text-center text-sm font-semibold leading-tight disabled:pointer-events-none disabled:opacity-60",
        toneClass,
      )}
    >
      {children}
    </button>
  );
}

function Badge({ children, tone = "neutral" }: { children: React.ReactNode; tone?: "green" | "amber" | "red" | "neutral" }) {
  const colors = {
    green: "bg-[#E8F5EF] text-[#0A7354] ring-[#B8DED0]",
    amber: "bg-[#FFF4DA] text-[#946200] ring-[#F1D08A]",
    red: "bg-[#FCE8E6] text-[#A23A35] ring-[#F1B7B2]",
    neutral: "bg-[#F4F8F6] text-[#64756F] ring-[#DCE7E3]",
  };
  return <span className={cx("inline-flex max-w-full items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1", colors[tone])}>{children}</span>;
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="grid min-w-0 gap-2 text-sm font-semibold text-[#294038]">
      {label}
      {children}
    </label>
  );
}

function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={cx(
        "min-h-11 w-full min-w-0 max-w-full rounded-lg border border-[#DCE7E3] bg-white px-3 text-sm text-[#10231F] outline-none transition focus:border-[#0A7354] focus:ring-4 focus:ring-[#0A7354]/10",
        props.className,
      )}
    />
  );
}

function Select(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className={cx(
        "min-h-11 w-full min-w-0 max-w-full rounded-lg border border-[#DCE7E3] bg-white px-3 text-sm text-[#10231F] outline-none transition focus:border-[#0A7354] focus:ring-4 focus:ring-[#0A7354]/10",
        props.className,
      )}
    />
  );
}

function Textarea(props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      {...props}
      className={cx(
        "min-h-28 w-full min-w-0 max-w-full rounded-lg border border-[#DCE7E3] bg-white px-3 py-3 text-sm text-[#10231F] outline-none transition focus:border-[#0A7354] focus:ring-4 focus:ring-[#0A7354]/10",
        props.className,
      )}
    />
  );
}

function SkeletonRows() {
  return (
    <div className="grid gap-3">
      {[0, 1, 2].map((item) => (
        <div key={item} className="skeleton h-16 rounded-lg" />
      ))}
    </div>
  );
}

function EmptyState({ icon: Icon, title, detail }: { icon: typeof Activity; title: string; detail: string }) {
  return (
    <div className="grid place-items-center rounded-lg border border-dashed border-[#DCE7E3] bg-[#F8FBFA] px-6 py-10 text-center">
      <div className="mb-3 grid h-12 w-12 place-items-center rounded-lg bg-[#E8F5EF]">
        <Icon className="h-6 w-6 text-[#0A7354]" />
      </div>
      <p className="text-sm font-bold text-[#10231F]">{title}</p>
      <p className="mt-1 max-w-md text-sm text-[#64756F]">{detail}</p>
    </div>
  );
}

function LoginScreen({ onToast }: { onToast: (toast: Omit<Toast, "id">) => void }) {
  const setToken = useAuthStore((state) => state.setToken);
  const queryClient = useQueryClient();
  const [email, setEmail] = useState("admin@brandt.local");
  const [password, setPassword] = useState("Admin123!");
  const mutation = useMutation({
    mutationFn: () => login(email, password),
    onSuccess: (token) => {
      setToken(token);
      queryClient.invalidateQueries();
      onToast({ tone: "success", title: "Acesso liberado", detail: "Sessao JWT iniciada com sucesso." });
    },
    onError: () => {
      onToast({ tone: "error", title: "Falha no login", detail: "Confira e-mail, senha e backend." });
    },
  });

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    mutation.mutate();
  }

  return (
    <main className="brand-surface soft-grid min-h-screen p-4 text-[#10231F] md:p-8">
      <div className="mx-auto grid min-h-[calc(100vh-4rem)] max-w-6xl items-center gap-8 lg:grid-cols-[1.1fr_0.9fr]">
        <motion.section
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55 }}
          className="space-y-8"
        >
          <div className="inline-flex items-center gap-2 rounded-full bg-white/85 px-4 py-2 text-sm font-semibold text-[#0A7354] shadow-sm ring-1 ring-[#DCE7E3]">
            <Sparkles className="h-4 w-4" />
            Produto oficial Brandt
          </div>
          <BrandtLogo />
          <div>
            <h1 className="max-w-3xl text-4xl font-semibold leading-tight text-[#10231F] md:text-6xl">
              Sistema de Acompanhamento Arqueologico
            </h1>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-[#64756F]">
              Coleta, sincronizacao e gestao de campo com identidade institucional Brandt, uso offline e rastreabilidade.
            </p>
          </div>
          <div className="grid gap-3 sm:grid-cols-3">
            {[
              ["Offline-first", "SQLite no app e sync REST"],
              ["Campo completo", "GPS, fotos e formularios"],
              ["Gestao premium", "Mapa, PDF, Excel e KMZ"],
            ].map(([title, detail]) => (
              <motion.div
                key={title}
                whileHover={{ y: -4 }}
                className="rounded-lg border border-[#DCE7E3] bg-white/82 p-4 shadow-sm backdrop-blur"
              >
                <p className="text-sm font-bold text-[#10231F]">{title}</p>
                <p className="mt-1 text-sm text-[#64756F]">{detail}</p>
              </motion.div>
            ))}
          </div>
        </motion.section>

        <motion.form
          onSubmit={handleSubmit}
          initial={{ opacity: 0, scale: 0.98, y: 18 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.08 }}
          className="glass rounded-lg p-6"
        >
          <div className="mb-6 flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-[#0A7354]">Entrada segura</p>
              <h2 className="text-2xl font-semibold text-[#10231F]">Acessar sistema</h2>
              <p className="mt-1 text-sm text-[#64756F]">Coleta, sincronizacao e gestao de campo</p>
            </div>
            <div className="brand-gradient rounded-lg p-3 text-white shadow-lg shadow-emerald-900/20">
              <Lock className="h-5 w-5" />
            </div>
          </div>
          <div className="grid gap-4">
            <Field label="E-mail">
              <TextInput type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
            </Field>
            <Field label="Senha">
              <TextInput type="password" value={password} onChange={(event) => setPassword(event.target.value)} required />
            </Field>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <ShieldCheck className="h-4 w-4" />}
              Entrar
            </Button>
          </div>
          <div className="mt-6 rounded-lg border border-[#DCE7E3] bg-[#F4F8F6] p-4 text-sm text-[#64756F]">
            <p className="font-semibold text-[#10231F]">Credencial inicial</p>
            <p>admin@brandt.local / Admin123!</p>
          </div>
        </motion.form>
      </div>
    </main>
  );
}

function Toasts({ items }: { items: Toast[] }) {
  return (
    <div className="fixed right-4 top-4 z-[1000] grid gap-3">
      <AnimatePresence>
        {items.map((toast) => (
          <motion.div
            key={toast.id}
            initial={{ opacity: 0, x: 18, scale: 0.98 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 18, scale: 0.98 }}
            className={cx(
              "w-80 rounded-lg border bg-white p-4 shadow-2xl",
              toast.tone === "success" && "border-emerald-200",
              toast.tone === "error" && "border-red-200",
              toast.tone === "info" && "border-slate-200",
            )}
          >
            <p className="font-semibold text-[#10231F]">{toast.title}</p>
            <p className="mt-1 text-sm text-[#64756F]">{toast.detail}</p>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}

function Shell({
  view,
  setView,
  me,
  children,
}: {
  view: View;
  setView: (view: View) => void;
  me: User;
  children: React.ReactNode;
}) {
  const setToken = useAuthStore((state) => state.setToken);
  const queryClient = useQueryClient();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen overflow-x-hidden bg-[#F4F8F6] text-[#10231F]">
      <motion.aside
        initial={false}
        animate={{
          x: sidebarOpen ? 0 : -288,
          opacity: sidebarOpen ? 1 : 0,
        }}
        transition={{ type: "spring", stiffness: 420, damping: 38, mass: 0.8 }}
        aria-hidden={!sidebarOpen}
        className={cx(
          "fixed inset-y-0 left-0 z-30 hidden w-72 border-r border-white/10 bg-[#061411] p-4 text-white shadow-2xl shadow-black/20 lg:block",
          sidebarOpen ? "pointer-events-auto" : "pointer-events-none",
        )}
      >
        <div className="mb-8 rounded-lg bg-white p-3 shadow-2xl shadow-black/20">
          <BrandtLogo compact />
          <p className="mt-2 text-xs font-semibold uppercase tracking-[0.18em] text-[#0A7354]">Arqueologia</p>
        </div>
        <nav className="grid gap-2">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = view === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => setView(item.id)}
                className={cx(
                  "flex items-center gap-3 rounded-lg px-3 py-3 text-left text-sm font-semibold transition",
                  active
                    ? "bg-white text-[#0A7354] shadow-xl"
                    : "text-white/68 hover:bg-white/10 hover:text-white",
                )}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </button>
            );
          })}
        </nav>
        <div className="absolute bottom-4 left-4 right-4 rounded-lg border border-white/10 bg-white/8 p-4">
          <p className="text-sm font-semibold">{me.name}</p>
          <p className="text-xs text-white/55">{formatRole[me.role.name] ?? me.role.name}</p>
          <button
            type="button"
            className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-white/75 hover:text-white"
            onClick={() => {
              setToken(null);
              queryClient.clear();
            }}
          >
            <LogOut className="h-4 w-4" />
            Sair
          </button>
        </div>
      </motion.aside>

      <div className={cx("min-w-0 transition-all duration-300 ease-out", sidebarOpen && "lg:pl-72")}>
        <header className="sticky top-0 z-20 min-w-0 border-b border-[#DCE7E3] bg-[#F4F8F6]/88 px-4 py-4 backdrop-blur-xl md:px-8">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              <button
                type="button"
                className="hidden h-10 w-10 shrink-0 place-items-center rounded-lg bg-white text-[#0A7354] shadow-sm ring-1 ring-[#DCE7E3] transition hover:bg-[#EAF4F0] lg:grid"
                onClick={() => setSidebarOpen((current) => !current)}
                aria-label={sidebarOpen ? "Esconder menu lateral" : "Mostrar menu lateral"}
                title={sidebarOpen ? "Esconder menu lateral" : "Mostrar menu lateral"}
              >
                {sidebarOpen ? <PanelLeftClose className="h-5 w-5" /> : <PanelLeftOpen className="h-5 w-5" />}
              </button>
              <div className="min-w-0">
                <p className="text-sm font-semibold text-[#0A7354]">Sistema de Acompanhamento Arqueologico</p>
                <h1 className="text-2xl font-semibold text-[#10231F]">{navItems.find((item) => item.id === view)?.label}</h1>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Badge tone="green">API REST</Badge>
              <Badge tone="amber">Offline-first</Badge>
            </div>
          </div>
          <motion.div
            initial={false}
            animate={{
              height: sidebarOpen ? 0 : "auto",
              marginTop: sidebarOpen ? 0 : 16,
              opacity: sidebarOpen ? 0 : 1,
              y: sidebarOpen ? -8 : 0,
            }}
            transition={{ duration: 0.22, ease: "easeOut" }}
            className={cx("flex gap-2 overflow-x-auto", sidebarOpen && "lg:pointer-events-none")}
          >
            {navItems.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setView(item.id)}
                  className={cx(
                    "inline-flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold",
                    view === item.id ? "brand-gradient text-white" : "bg-white text-[#10231F] ring-1 ring-[#DCE7E3]",
                  )}
                >
                  <Icon className="h-4 w-4" />
                  {item.label}
                </button>
              );
            })}
          </motion.div>
        </header>
        <motion.main
          key={view}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.25 }}
          className="min-w-0 overflow-x-hidden p-4 md:p-8"
        >
          {children}
        </motion.main>
      </div>
    </div>
  );
}

function Dashboard({ projects, collections, forms }: { projects: Project[]; collections: Collection[]; forms: DynamicForm[] }) {
  const vestigios = collections.filter((item) => getAnswer(item, "vestigio_identificado") === true).length;
  const intercorrencias = collections.filter((item) => getAnswer(item, "intercorrencia_identificada") === true).length;
  const pending = collections.filter((item) => item.sync_status !== "synced").length;
  const synced = collections.filter((item) => item.sync_status === "synced").length;
  const chartData = projects.map((project) => ({
    name: project.code || project.name.slice(0, 12),
    coletas: collections.filter((item) => item.project_id === project.id).length,
  }));
  const trend = ["Rascunho", "Pendente", "Sincronizado", "Revisado"].map((name) => ({
    name,
    total: collections.filter((item) => item.status.toLowerCase().includes(name.toLowerCase().slice(0, 5))).length,
  }));
  const syncRows: Array<[string, number, "green" | "amber" | "red" | "neutral"]> = [
    ["Sincronizadas", synced, "green"],
    ["Pendentes/erro", pending, pending ? "amber" : "neutral"],
    ["Formulario publicado", forms.filter((form) => form.status === "published").length, "green"],
  ];

  return (
    <div className="grid min-w-0 gap-6">
      <section className="grid min-w-0 gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {[
          { label: "Total de coletas", value: collections.length, icon: Archive, tone: "from-[#0A7354]/12 to-[#0F486E]/8" },
          { label: "Sincronizadas", value: synced, icon: Cloud, tone: "from-[#339A51]/12 to-[#0A7354]/8" },
          { label: "Pendencias", value: pending, icon: UploadCloud, tone: "from-[#D8A23F]/18 to-[#0A7354]/6" },
          { label: "Vestigios", value: vestigios, icon: Sparkles, tone: "from-[#0F486E]/12 to-[#339A51]/8" },
          { label: "Intercorrencias", value: intercorrencias, icon: BadgeCheck, tone: "from-[#A23A35]/10 to-[#0F486E]/6" },
          { label: "Projetos ativos", value: projects.length, icon: Building2, tone: "from-[#0A7354]/12 to-[#339A51]/8" },
        ].map((card, index) => {
          const Icon = card.icon;
          return (
            <motion.div
              key={card.label}
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.04 }}
              whileHover={{ y: -4 }}
              className={cx("brand-card min-w-0 bg-gradient-to-br p-5 transition", card.tone)}
            >
              <div className="flex items-center justify-between">
                <div className="grid h-11 w-11 place-items-center rounded-lg bg-white shadow-sm ring-1 ring-[#DCE7E3]">
                  <Icon className="h-5 w-5 text-[#0A7354]" />
                </div>
                <ChevronDown className="h-4 w-4 text-[#64756F]" />
              </div>
              <p className="mt-6 text-3xl font-semibold text-[#10231F]">{card.value}</p>
              <p className="text-sm text-[#64756F]">{card.label}</p>
            </motion.div>
          );
        })}
      </section>

      <section className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
        <div className="brand-card min-w-0 p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold">Coletas por projeto</h2>
              <p className="text-sm text-[#64756F]">Grafico animado alimentado pela API.</p>
            </div>
            <Badge tone="green">{collections.length} registros</Badge>
          </div>
          <div className="h-80 min-w-0">
            <ResponsiveContainer width="100%" height="100%" minWidth={0} initialDimension={{ width: 1, height: 1 }}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke={brand.border} />
                <XAxis dataKey="name" />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Bar dataKey="coletas" fill={brand.green} radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="brand-card min-w-0 p-5">
          <div className="mb-4">
            <h2 className="text-lg font-semibold">Sinais de campo</h2>
            <p className="text-sm text-[#64756F]">Vestigios, intercorrencias e fluxo de revisao.</p>
          </div>
          <div className="grid gap-3">
            <div className="rounded-lg bg-[#F4F8F6] p-4">
              <p className="text-sm text-[#64756F]">Vestigios identificados</p>
              <p className="text-2xl font-semibold">{vestigios}</p>
            </div>
            <div className="rounded-lg bg-[#F4F8F6] p-4">
              <p className="text-sm text-[#64756F]">Intercorrencias</p>
              <p className="text-2xl font-semibold">{intercorrencias}</p>
            </div>
          </div>
          <div className="mt-5 h-44 min-w-0">
            <ResponsiveContainer width="100%" height="100%" minWidth={0} initialDimension={{ width: 1, height: 1 }}>
              <AreaChart data={trend}>
                <defs>
                  <linearGradient id="statusFill" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="5%" stopColor={brand.blue} stopOpacity={0.55} />
                    <stop offset="95%" stopColor={brand.green} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="name" hide />
                <YAxis hide />
                <Tooltip />
                <Area type="monotone" dataKey="total" stroke={brand.blue} fill="url(#statusFill)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </section>

      <section className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
        <div className="brand-card min-w-0 p-5">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold">Status de sincronizacao</h2>
              <p className="text-sm text-[#64756F]">Resumo executivo do fluxo mobile.</p>
            </div>
            <Smartphone className="h-5 w-5 text-[#0A7354]" />
          </div>
          <div className="mt-5 grid gap-3">
            {syncRows.map(([label, value, tone]) => (
              <div key={label} className="flex items-center justify-between rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-3">
                <span className="text-sm font-semibold text-[#10231F]">{label}</span>
                <Badge tone={tone}>{value}</Badge>
              </div>
            ))}
          </div>
        </div>
        <div className="brand-card min-w-0 p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold">Coletas recentes</h2>
              <p className="text-sm text-[#64756F]">Ultimos registros recebidos pela web.</p>
            </div>
            <Badge>{collections.slice(0, 5).length} exibidas</Badge>
          </div>
          <div className="grid gap-3">
            {collections.slice(0, 5).length ? (
              collections.slice(0, 5).map((collection) => (
                <div key={collection.id} className="flex min-w-0 items-center justify-between gap-3 rounded-lg bg-[#F8FBFA] p-3">
                  <div className="min-w-0">
                    <p className="font-semibold text-[#10231F]">{collection.collection_date || "Sem data"}</p>
                    <p className="truncate text-sm text-[#64756F]">{String(getAnswer(collection, "activity_description") ?? "Sem descricao").slice(0, 90)}</p>
                  </div>
                  <Badge tone={collection.status === "reviewed" ? "green" : "amber"}>{collection.status}</Badge>
                </div>
              ))
            ) : (
              <EmptyState icon={Archive} title="Sem coletas recentes" detail="As coletas sincronizadas pelo app aparecerao neste painel." />
            )}
          </div>
        </div>
      </section>

      <CollectionMap collections={collections} projects={projects} compact />
    </div>
  );
}

function UsersView({
  users,
  projects,
  forms,
  onToast,
}: {
  users: User[];
  projects: Project[];
  forms: DynamicForm[];
  onToast: (toast: Omit<Toast, "id">) => void;
}) {
  const queryClient = useQueryClient();
  const emptyDraft = {
    name: "",
    email: "",
    password: "Brandt123!",
    role: "archaeologist",
    is_active: true,
    project_ids: [] as string[],
    form_ids: [] as string[],
  };
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [userFilter, setUserFilter] = useState("");
  const selectedUser = users.find((user) => user.id === selectedUserId) ?? null;
  const selectedProjectIds = new Set(draft.project_ids);
  const availableForms = forms.filter((form) => selectedProjectIds.has(form.project_id));
  const filteredUsers = useMemo(() => {
    const normalized = userFilter.trim().toLowerCase();
    if (!normalized) return users;
    return users.filter((user) => {
      const roleLabel = formatRole[user.role.name] ?? user.role.name;
      return [user.name, user.email, roleLabel].some((value) => value.toLowerCase().includes(normalized));
    });
  }, [userFilter, users]);
  const saveMutation = useMutation({
    mutationFn: () => {
      const payload = {
        name: draft.name,
        email: draft.email,
        role: draft.role,
        is_active: draft.is_active,
        project_ids: draft.project_ids,
        form_ids: draft.form_ids,
        ...(draft.password ? { password: draft.password } : {}),
      };
      if (selectedUser) return api.put(`/users/${selectedUser.id}`, payload);
      return api.post("/users", payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
      onToast({
        tone: "success",
        title: selectedUser ? "Usuario atualizado" : "Usuario criado",
        detail: "Senha, perfil e vinculos foram salvos.",
      });
      if (selectedUser) {
        setDraft((current) => ({ ...current, password: "" }));
      } else {
        setDraft(emptyDraft);
      }
    },
    onError: () => onToast({ tone: "error", title: "Erro ao salvar usuario", detail: "Verifique senha minima, e-mail duplicado ou vinculos." }),
  });

  function startCreate() {
    setSelectedUserId(null);
    setDraft(emptyDraft);
  }

  function startEdit(user: User) {
    setSelectedUserId(user.id);
    setDraft({
      name: user.name,
      email: user.email,
      password: "",
      role: user.role.name,
      is_active: user.is_active,
      project_ids: user.project_ids ?? [],
      form_ids: user.form_ids ?? [],
    });
  }

  function toggleProject(projectId: string, checked: boolean) {
    setDraft((current) => {
      const projectIds = checked
        ? [...new Set([...current.project_ids, projectId])]
        : current.project_ids.filter((id) => id !== projectId);
      const allowedProjectIds = new Set(projectIds);
      const formIds = current.form_ids.filter((formId) => {
        const form = forms.find((item) => item.id === formId);
        return form ? allowedProjectIds.has(form.project_id) : false;
      });
      return { ...current, project_ids: projectIds, form_ids: formIds };
    });
  }

  function toggleForm(formId: string, checked: boolean) {
    setDraft((current) => ({
      ...current,
      form_ids: checked ? [...new Set([...current.form_ids, formId])] : current.form_ids.filter((id) => id !== formId),
    }));
  }

  return (
    <div className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(340px,420px)]">
      <section className="brand-card min-w-0 p-5">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold">Usuarios e permissoes</h2>
            <p className="text-sm text-[#64756F]">Clique em uma linha para editar senha, perfil e acessos.</p>
          </div>
          <div className="relative w-full sm:w-64">
            <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-[#64756F]" />
            <TextInput
              aria-label="Filtrar usuarios"
              className="pl-9"
              placeholder="Filtrar visualmente"
              value={userFilter}
              onChange={(event) => setUserFilter(event.target.value)}
            />
          </div>
        </div>
        {users.length === 0 ? (
          <EmptyState icon={UsersRound} title="Nenhum usuario cadastrado" detail="Crie o primeiro usuario no painel lateral." />
        ) : filteredUsers.length === 0 ? (
          <EmptyState icon={Search} title="Nenhum usuario encontrado" detail="Ajuste o filtro visual para voltar a listar os usuarios." />
        ) : (
          <div className="max-w-full overflow-x-auto">
            <table className="w-full min-w-[840px] border-separate border-spacing-y-2 text-left text-sm">
              <thead className="text-xs uppercase text-[#64756F]">
                <tr>
                  <th className="px-3 py-2">Nome</th>
                  <th className="px-3 py-2">E-mail</th>
                  <th className="px-3 py-2">Perfil</th>
                  <th className="px-3 py-2">Acessos</th>
                  <th className="px-3 py-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user, index) => (
                  <motion.tr
                    key={user.id}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.025 }}
                    onClick={() => startEdit(user)}
                    className={cx(
                      "cursor-pointer bg-white shadow-sm ring-1 ring-[#DCE7E3]/70 transition hover:bg-[#F8FBFA]",
                      selectedUserId === user.id && "ring-2 ring-[#0A7354]",
                    )}
                  >
                    <td className="rounded-l-lg px-3 py-4">
                      <div className="flex min-w-0 items-center gap-3">
                        <div className="brand-gradient grid h-10 w-10 shrink-0 place-items-center rounded-lg text-sm font-bold text-white">
                          {initials(user.name)}
                        </div>
                        <span className="min-w-0 truncate font-semibold text-[#10231F]" title={user.name}>{user.name}</span>
                      </div>
                    </td>
                    <td className="px-3 py-4 text-[#64756F]">{user.email}</td>
                    <td className="px-3 py-4">
                      <Badge>{formatRole[user.role.name] ?? user.role.name}</Badge>
                    </td>
                    <td className="px-3 py-4">
                      <div className="flex flex-wrap gap-2">
                        <Badge>{user.project_ids?.length ?? 0} projetos</Badge>
                        <Badge>{user.form_ids?.length ?? 0} formularios</Badge>
                      </div>
                    </td>
                    <td className="rounded-r-lg px-3 py-4">
                      <Badge tone={user.is_active ? "green" : "red"}>{user.is_active ? "Ativo" : "Inativo"}</Badge>
                    </td>
                  </motion.tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <aside className="brand-card min-w-0 p-5">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-lg font-semibold">{selectedUser ? "Editar usuario" : "Novo usuario"}</h2>
            <p className="mt-1 text-sm text-[#64756F]">
              {selectedUser ? "Altere senha, perfil e vinculos de acesso." : "Crie usuario com projetos e formularios liberados."}
            </p>
          </div>
          {selectedUser ? (
            <Button tone="ghost" onClick={startCreate}>
              <Plus className="h-4 w-4" />
              Novo
            </Button>
          ) : null}
        </div>
        <form
          className="mt-4 grid min-w-0 gap-4"
          onSubmit={(event) => {
            event.preventDefault();
            if (!selectedUser && !draft.password) {
              onToast({ tone: "error", title: "Senha obrigatoria", detail: "Informe uma senha inicial para criar o usuario." });
              return;
            }
            saveMutation.mutate();
          }}
        >
          <Field label="Nome">
            <TextInput value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} required />
          </Field>
          <Field label="E-mail">
            <TextInput type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} required />
          </Field>
          <Field label={selectedUser ? "Nova senha" : "Senha inicial"}>
            <TextInput
              value={draft.password}
              onChange={(event) => setDraft({ ...draft, password: event.target.value })}
              placeholder={selectedUser ? "Deixe em branco para manter" : "Minimo 8 caracteres"}
              required={!selectedUser}
            />
          </Field>
          <Field label="Perfil">
            <Select value={draft.role} onChange={(event) => setDraft({ ...draft, role: event.target.value })}>
              {Object.entries(formatRole).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </Select>
          </Field>
          <label className="flex items-center gap-2 text-sm font-semibold text-[#294038]">
            <input
              type="checkbox"
              checked={draft.is_active}
              onChange={(event) => setDraft({ ...draft, is_active: event.target.checked })}
            />
            Usuario ativo
          </label>
          <div className="grid min-w-0 gap-2">
            <p className="text-sm font-semibold text-[#294038]">Projetos vinculados</p>
            <div className="grid max-h-40 gap-2 overflow-y-auto rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-3">
              {projects.length ? (
                projects.map((project) => (
                  <label key={project.id} className="flex min-w-0 items-start gap-2 text-sm">
                    <input
                      className="mt-1"
                      type="checkbox"
                      checked={draft.project_ids.includes(project.id)}
                      onChange={(event) => toggleProject(project.id, event.target.checked)}
                    />
                    <span className="min-w-0">
                      <span className="block break-words font-semibold text-[#10231F]">{project.name}</span>
                      <span className="text-xs text-[#64756F]">{project.code || project.status}</span>
                    </span>
                  </label>
                ))
              ) : (
                <p className="text-sm text-[#64756F]">Nenhum projeto cadastrado.</p>
              )}
            </div>
          </div>
          <div className="grid min-w-0 gap-2">
            <p className="text-sm font-semibold text-[#294038]">Formularios vinculados</p>
            <div className="grid max-h-48 gap-2 overflow-y-auto rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-3">
              {availableForms.length ? (
                availableForms.map((form) => (
                  <label key={form.id} className="flex min-w-0 items-start gap-2 text-sm">
                    <input
                      className="mt-1"
                      type="checkbox"
                      checked={draft.form_ids.includes(form.id)}
                      onChange={(event) => toggleForm(form.id, event.target.checked)}
                    />
                    <span className="min-w-0">
                      <span className="block break-words font-semibold text-[#10231F]">{form.name}</span>
                      <span className="text-xs text-[#64756F]">
                        {projects.find((project) => project.id === form.project_id)?.name || "Projeto"} - {form.status}
                      </span>
                    </span>
                  </label>
                ))
              ) : (
                <p className="text-sm text-[#64756F]">Selecione um projeto para liberar formularios.</p>
              )}
            </div>
          </div>
          <Button type="submit" disabled={saveMutation.isPending}>
            {saveMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : selectedUser ? <Save className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
            {selectedUser ? "Salvar usuario" : "Criar usuario"}
          </Button>
        </form>
      </aside>
    </div>
  );
}

function ProjectsView({ projects, onToast }: { projects: Project[]; onToast: (toast: Omit<Toast, "id">) => void }) {
  const queryClient = useQueryClient();
  const [selectedProjectId, setSelectedProjectId] = useState(projects[0]?.id ?? "");
  const activeProjectId = selectedProjectId || projects[0]?.id || "";
  const [projectDraft, setProjectDraft] = useState({ name: "", code: "", description: "" });
  const [sectionDraft, setSectionDraft] = useState("");
  const [pointDraft, setPointDraft] = useState("");
  const sectionsQuery = useQuery({
    queryKey: ["sections", activeProjectId],
    queryFn: () => getSections(activeProjectId),
    enabled: Boolean(activeProjectId),
  });
  const selectedSectionId = sectionsQuery.data?.[0]?.id ?? "";
  const pointsQuery = useQuery({
    queryKey: ["work-points", selectedSectionId],
    queryFn: () => getWorkPoints(selectedSectionId),
    enabled: Boolean(selectedSectionId),
  });
  const createProject = useMutation({
    mutationFn: () => api.post("/projects", { ...projectDraft, status: "active" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["projects"] });
      onToast({ tone: "success", title: "Projeto criado", detail: "Novo projeto disponivel para vinculos e formularios." });
      setProjectDraft({ name: "", code: "", description: "" });
    },
  });
  const createSection = useMutation({
    mutationFn: () => api.post(`/projects/${activeProjectId}/sections`, { name: sectionDraft, order_index: (sectionsQuery.data?.length ?? 0) + 1 }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["sections", activeProjectId] });
      onToast({ tone: "success", title: "Trecho criado", detail: "Trecho incluido no projeto selecionado." });
      setSectionDraft("");
    },
  });
  const createPoint = useMutation({
    mutationFn: () => api.post(`/sections/${selectedSectionId}/work-points`, { name: pointDraft, order_index: (pointsQuery.data?.length ?? 0) + 1 }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["work-points", selectedSectionId] });
      onToast({ tone: "success", title: "Ponto criado", detail: "Ponto de obra disponivel para coletas." });
      setPointDraft("");
    },
  });

  return (
    <div className="grid min-w-0 gap-6">
      <section className="grid min-w-0 gap-4 xl:grid-cols-3">
        {projects.map((project, index) => (
          <motion.button
            key={project.id}
            type="button"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.035 }}
            whileHover={{ y: -4 }}
            onClick={() => setSelectedProjectId(project.id)}
            className={cx(
              "brand-card min-w-0 p-5 text-left transition",
              activeProjectId === project.id && "ring-2 ring-[#2f6f5e]",
            )}
          >
            <div className="flex items-center justify-between">
              <Badge tone="green">{project.status}</Badge>
              <div className="grid h-10 w-10 place-items-center rounded-lg bg-[#E8F5EF]">
                <Route className="h-5 w-5 text-[#0A7354]" />
              </div>
            </div>
            <h2 className="mt-5 break-words text-lg font-semibold text-[#10231F]">{project.name}</h2>
            <p className="mt-2 break-words text-sm text-[#64756F]">{project.description || "Sem descricao"}</p>
            <div className="mt-5 grid grid-cols-3 gap-2 text-center text-xs font-semibold text-[#64756F]">
              <div className="rounded-lg bg-[#F4F8F6] p-2">Trechos</div>
              <div className="rounded-lg bg-[#F4F8F6] p-2">Pontos</div>
              <div className="rounded-lg bg-[#F4F8F6] p-2">Forms</div>
            </div>
          </motion.button>
        ))}
      </section>

      <section className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(320px,360px)]">
        <div className="brand-card min-w-0 p-5">
          <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold">Trechos e pontos</h2>
              <p className="text-sm text-[#64756F]">Pontos sao carregados conforme o primeiro trecho selecionado.</p>
            </div>
            <Badge>{sectionsQuery.data?.length ?? 0} trechos</Badge>
          </div>
          {sectionsQuery.isLoading ? (
            <SkeletonRows />
          ) : (
            <div className="grid min-w-0 gap-4 lg:grid-cols-2">
              <div className="grid gap-3">
                {(sectionsQuery.data ?? []).map((section) => (
                  <div key={section.id} className="min-w-0 rounded-lg border border-[#DCE7E3] bg-white p-4 shadow-sm">
                    <p className="break-words font-semibold text-[#10231F]">{section.name}</p>
                    <p className="text-sm text-[#64756F]">Ordem {section.order_index}</p>
                  </div>
                ))}
              </div>
              <div className="grid gap-3">
                {(pointsQuery.data ?? []).map((point) => (
                  <div key={point.id} className="flex min-w-0 items-center justify-between gap-3 rounded-lg bg-[#F4F8F6] p-4">
                    <span className="min-w-0 break-words font-semibold">{point.name}</span>
                    <Badge tone={point.is_active ? "green" : "red"}>{point.is_active ? "Ativo" : "Inativo"}</Badge>
                  </div>
                ))}
                <div className="rounded-lg border border-dashed border-[#DCE7E3] p-4">
                  <p className="font-semibold">Opcao condicional</p>
                  <p className="text-sm text-[#64756F]">O app e o formulario aceitam "Outro" e exigem "Qual?".</p>
                </div>
              </div>
            </div>
          )}
        </div>
        <aside className="grid min-w-0 gap-4">
          <form
            className="brand-card min-w-0 p-5"
            onSubmit={(event) => {
              event.preventDefault();
              createProject.mutate();
            }}
          >
            <h2 className="text-lg font-semibold">Novo projeto</h2>
            <div className="mt-4 grid gap-3">
              <TextInput placeholder="Nome" value={projectDraft.name} onChange={(event) => setProjectDraft({ ...projectDraft, name: event.target.value })} />
              <TextInput placeholder="Codigo" value={projectDraft.code} onChange={(event) => setProjectDraft({ ...projectDraft, code: event.target.value })} />
              <Textarea placeholder="Descricao" value={projectDraft.description} onChange={(event) => setProjectDraft({ ...projectDraft, description: event.target.value })} />
              <Button type="submit">
                <Plus className="h-4 w-4" />
                Criar projeto
              </Button>
            </div>
          </form>
          <form
            className="brand-card min-w-0 p-5"
            onSubmit={(event) => {
              event.preventDefault();
              createSection.mutate();
            }}
          >
            <h2 className="text-lg font-semibold">Novo trecho</h2>
            <div className="mt-4 grid gap-3">
              <TextInput placeholder="Trecho 04" value={sectionDraft} onChange={(event) => setSectionDraft(event.target.value)} />
              <Button type="submit" disabled={!activeProjectId}>
                <Plus className="h-4 w-4" />
                Adicionar trecho
              </Button>
            </div>
          </form>
          <form
            className="brand-card min-w-0 p-5"
            onSubmit={(event) => {
              event.preventDefault();
              createPoint.mutate();
            }}
          >
            <h2 className="text-lg font-semibold">Novo ponto</h2>
            <div className="mt-4 grid gap-3">
              <TextInput placeholder="017+250" value={pointDraft} onChange={(event) => setPointDraft(event.target.value)} />
              <Button type="submit" disabled={!selectedSectionId}>
                <Plus className="h-4 w-4" />
                Adicionar ponto
              </Button>
            </div>
          </form>
        </aside>
      </section>
    </div>
  );
}

function FormsView({ forms, projects, onToast }: { forms: DynamicForm[]; projects: Project[]; onToast: (toast: Omit<Toast, "id">) => void }) {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState(forms[0]?.id ?? "");
  const selected = forms.find((form) => form.id === selectedId) ?? forms[0];
  const [fields, setFields] = useState<FormField[]>(selected?.fields ?? []);
  const [name, setName] = useState(selected?.name ?? "");
  const [projectId, setProjectId] = useState(selected?.project_id ?? projects[0]?.id ?? "");
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [selectedFieldIndex, setSelectedFieldIndex] = useState(0);

  const saveMutation = useMutation({
    mutationFn: () => {
      const payload = {
        project_id: projectId,
        name,
        description: "Formulario dinamico gerenciado pelo builder web.",
        status: selected?.status ?? "draft",
        fields: fields.map((field, index) => ({ ...field, order_index: index + 1 })),
      };
      if (selected) return api.put(`/forms/${selected.id}`, payload);
      return api.post("/forms", payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["forms"] });
      onToast({ tone: "success", title: "Formulario salvo", detail: "Campos e versao foram atualizados." });
    },
  });
  const publishMutation = useMutation({
    mutationFn: () => api.post(`/forms/${selected?.id}/publish`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["forms"] });
      onToast({ tone: "success", title: "Formulario publicado", detail: "Versao liberada para o app Android." });
    },
  });

  function addField() {
    setFields((current) => [
      ...current,
      {
        label: "Novo campo",
        field_key: `campo_${current.length + 1}`,
        field_type: "text",
        is_required: false,
        order_index: current.length + 1,
      },
    ]);
    setSelectedFieldIndex(fields.length);
  }

  function reorder(targetIndex: number) {
    if (dragIndex === null || dragIndex === targetIndex) return;
    const next = [...fields];
    const [removed] = next.splice(dragIndex, 1);
    next.splice(targetIndex, 0, removed);
    setFields(next.map((field, index) => ({ ...field, order_index: index + 1 })));
    setDragIndex(null);
  }

  return (
    <div className="grid min-w-0 gap-6 2xl:grid-cols-[minmax(260px,300px)_minmax(0,1fr)_minmax(300px,340px)]">
      <aside className="brand-card min-w-0 p-5">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Biblioteca</h2>
          <Button
            tone="ghost"
            onClick={() => {
              setSelectedId("");
              setName("Novo formulario");
              setProjectId(projects[0]?.id ?? "");
              setFields([]);
              setSelectedFieldIndex(0);
            }}
          >
            <Plus className="h-4 w-4" />
          </Button>
        </div>
        <div className="mt-4 grid gap-2">
          {[
            ["Texto curto", "text", FileText],
            ["Texto longo", "textarea", FileText],
            ["Lista", "select", ChevronDown],
            ["Foto", "photo", Camera],
            ["GPS", "coordinate", MapPinned],
            ["Sim/Nao", "boolean", BadgeCheck],
          ].map(([label, type, Icon]) => (
            <button
              key={String(type)}
              type="button"
              onClick={() => {
                setFields((current) => [
                  ...current,
                  {
                    label: String(label),
                    field_key: `${String(type)}_${current.length + 1}`,
                    field_type: String(type),
                    is_required: false,
                    order_index: current.length + 1,
                  },
                ]);
                setSelectedFieldIndex(fields.length);
              }}
              className="flex min-w-0 items-center gap-3 rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-3 text-left text-sm font-semibold text-[#10231F] transition hover:border-[#0A7354] hover:bg-white"
            >
              <Icon className="h-4 w-4 shrink-0 text-[#0A7354]" />
              <span className="min-w-0 truncate">{String(label)}</span>
            </button>
          ))}
        </div>
        <div className="mt-6 border-t border-[#DCE7E3] pt-4">
          <p className="mb-3 text-xs font-bold uppercase tracking-[0.14em] text-[#64756F]">Formularios</p>
        <div className="mt-4 grid min-w-0 gap-3">
          {forms.map((form) => (
            <button
              key={form.id}
              type="button"
              onClick={() => {
                setSelectedId(form.id);
                setFields([...form.fields].sort((a, b) => a.order_index - b.order_index));
                setName(form.name);
                setProjectId(form.project_id);
                setSelectedFieldIndex(0);
              }}
              className={cx(
                "min-w-0 rounded-lg p-4 text-left transition",
                selected?.id === form.id ? "brand-gradient text-white" : "bg-white hover:bg-[#F4F8F6]",
              )}
            >
              <p className="truncate font-semibold" title={form.name}>{form.name}</p>
              <p className={cx("text-sm", selected?.id === form.id ? "text-white/70" : "text-[#64756F]")}>
                v{form.current_version} - {form.status}
              </p>
            </button>
          ))}
        </div>
        </div>
      </aside>

      <section className="brand-card min-w-0 p-5">
        <div className="mb-5 grid min-w-0 gap-3 md:grid-cols-2">
          <Field label="Nome do formulario">
            <TextInput value={name} onChange={(event) => setName(event.target.value)} />
          </Field>
          <Field label="Projeto">
            <Select value={projectId} onChange={(event) => setProjectId(event.target.value)}>
              {projects.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold">Builder dinamico</h2>
            <p className="text-sm text-[#64756F]">Canvas do formulario com drag and drop, badges e microinteracoes.</p>
          </div>
          <Button onClick={addField}>
            <Plus className="h-4 w-4" />
            Campo
          </Button>
        </div>
        <div className="grid min-w-0 gap-3">
          <AnimatePresence initial={false}>
            {fields.map((field, index) => (
              <motion.div
                key={`${field.field_key}-${index}`}
                draggable
                onDragStart={() => setDragIndex(index)}
                onDragOver={(event) => event.preventDefault()}
                onDrop={() => reorder(index)}
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.98 }}
                onClick={() => setSelectedFieldIndex(index)}
                className={cx(
                  "min-w-0 rounded-lg border bg-white p-4 shadow-sm transition",
                  selectedFieldIndex === index ? "border-[#0A7354] ring-4 ring-[#0A7354]/10" : "border-[#DCE7E3]",
                )}
              >
                <div className="grid min-w-0 gap-3 2xl:grid-cols-[minmax(0,1fr)_150px_130px_76px]">
                  <TextInput
                    value={field.label}
                    onChange={(event) => {
                      const next = [...fields];
                      next[index] = { ...field, label: event.target.value };
                      setFields(next);
                    }}
                  />
                  <Select
                    value={field.field_type}
                    onChange={(event) => {
                      const next = [...fields];
                      next[index] = { ...field, field_type: event.target.value };
                      setFields(next);
                    }}
                  >
                    {fieldTypes.map((type) => (
                      <option key={type} value={type}>
                        {type}
                      </option>
                    ))}
                  </Select>
                  <TextInput
                    value={field.field_key}
                    onChange={(event) => {
                      const next = [...fields];
                      next[index] = { ...field, field_key: event.target.value };
                      setFields(next);
                    }}
                  />
                  <label className="flex items-center gap-2 text-sm font-semibold">
                    <input
                      type="checkbox"
                      checked={field.is_required}
                      onChange={(event) => {
                        const next = [...fields];
                        next[index] = { ...field, is_required: event.target.checked };
                        setFields(next);
                      }}
                    />
                    Req.
                  </label>
                </div>
                {field.conditional_logic ? (
                  <Badge tone="amber">Condicional</Badge>
                ) : (
                  <button
                    type="button"
                    className="mt-3 text-xs font-semibold text-[#0A7354]"
                    onClick={() => {
                      const next = [...fields];
                      next[index] = {
                        ...field,
                        conditional_logic: { field: "vestigio_identificado", operator: "equals", value: true },
                      };
                      setFields(next);
                    }}
                  >
                    Adicionar regra condicional
                  </button>
                )}
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
        <div className="mt-5 flex flex-wrap gap-3">
          <Button onClick={() => saveMutation.mutate()} disabled={saveMutation.isPending}>
            <Save className="h-4 w-4" />
            Salvar
          </Button>
          <Button tone="secondary" onClick={() => publishMutation.mutate()} disabled={!selected || publishMutation.isPending}>
            <BadgeCheck className="h-4 w-4" />
            Publicar
          </Button>
        </div>
      </section>

      <aside className="brand-card min-w-0 p-5">
        <h2 className="text-lg font-semibold">Propriedades</h2>
        {fields[selectedFieldIndex] ? (
          <div className="mt-4 grid min-w-0 gap-3 rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-4">
            <p className="break-words text-sm font-semibold text-[#10231F]">{fields[selectedFieldIndex].label}</p>
            <Badge tone={fields[selectedFieldIndex].is_required ? "red" : "neutral"}>
              {fields[selectedFieldIndex].is_required ? "Obrigatorio" : "Opcional"}
            </Badge>
            <Badge tone={fields[selectedFieldIndex].field_type === "photo" || fields[selectedFieldIndex].field_type === "coordinate" ? "green" : "neutral"}>
              {fields[selectedFieldIndex].field_type}
            </Badge>
            {fields[selectedFieldIndex].conditional_logic ? <Badge tone="amber">Condicional</Badge> : null}
          </div>
        ) : (
          <EmptyState icon={FormInput} title="Nenhum campo selecionado" detail="Selecione um campo no canvas para editar suas propriedades." />
        )}
        <h2 className="mt-6 text-lg font-semibold">Preview</h2>
        <div className="mt-4 grid min-w-0 gap-3">
          {fields.length === 0 ? (
            <EmptyState icon={FormInput} title="Sem campos" detail="Adicione campos para visualizar o formulario." />
          ) : (
            fields.map((field) => (
              <motion.div key={field.field_key} layout className="min-w-0 rounded-lg bg-[#F8FBFA] p-4">
                <div className="mb-2 flex min-w-0 items-center justify-between gap-2">
                  <p className="min-w-0 break-words text-sm font-semibold">{field.label}</p>
                  {field.is_required && <Badge tone="red">Obrigatorio</Badge>}
                </div>
                {field.field_type === "textarea" ? <Textarea disabled placeholder={field.field_key} /> : <TextInput disabled placeholder={field.field_key} />}
              </motion.div>
            ))
          )}
        </div>
      </aside>
    </div>
  );
}

function CollectionsView({ collections, projects, forms, onToast }: { collections: Collection[]; projects: Project[]; forms: DynamicForm[]; onToast: (toast: Omit<Toast, "id">) => void }) {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState<string | null>(collections[0]?.id ?? null);
  const selected = collections.find((collection) => collection.id === selectedId) ?? collections[0] ?? null;
  const reviewMutation = useMutation({
    mutationFn: (id: string) => api.put(`/collections/${id}/review`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["collections"] });
      onToast({ tone: "success", title: "Coleta revisada", detail: "Status atualizado para reviewed." });
    },
  });

  return (
    <div className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(320px,400px)]">
      <section className="brand-card min-w-0 p-5">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold">Consulta de coletas</h2>
            <p className="text-sm text-[#64756F]">Filtros visuais, status e exportacoes conectadas ao backend.</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <a className="premium-btn inline-flex min-h-10 items-center gap-2 rounded-lg bg-white px-4 text-sm font-semibold shadow-sm ring-1 ring-[#DCE7E3]" href={exportUrl("/exports/collections.xlsx")}>
              <FileSpreadsheet className="h-4 w-4" />
              Excel
            </a>
            <a className="premium-btn inline-flex min-h-10 items-center gap-2 rounded-lg bg-white px-4 text-sm font-semibold shadow-sm ring-1 ring-[#DCE7E3]" href={exportUrl("/exports/collections.kmz")}>
              <Download className="h-4 w-4" />
              KMZ
            </a>
          </div>
        </div>
        {collections.length === 0 ? (
          <EmptyState icon={Archive} title="Nenhuma coleta sincronizada" detail="As coletas do app aparecerao aqui apos o POST /mobile/sync." />
        ) : (
          <div className="max-w-full overflow-x-auto">
            <table className="w-full min-w-[900px] border-separate border-spacing-y-2 text-left text-sm">
              <thead className="text-xs uppercase text-[#64756F]">
                <tr>
                  <th className="px-3 py-2">Data</th>
                  <th className="px-3 py-2">Projeto</th>
                  <th className="px-3 py-2">Formulario</th>
                  <th className="px-3 py-2">Resumo</th>
                  <th className="px-3 py-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {collections.map((collection, index) => (
                  <motion.tr
                    key={collection.id}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.02 }}
                    onClick={() => setSelectedId(collection.id)}
                    className="cursor-pointer bg-white shadow-sm ring-1 ring-[#DCE7E3]/70 transition hover:bg-[#F8FBFA]"
                  >
                    <td className="rounded-l-lg px-3 py-4">{collection.collection_date || "-"}</td>
                    <td className="px-3 py-4">{projects.find((project) => project.id === collection.project_id)?.code || "Projeto"}</td>
                    <td className="px-3 py-4">{forms.find((form) => form.id === collection.form_id)?.name || "Formulario"}</td>
                    <td className="px-3 py-4 text-[#64756F]">{String(getAnswer(collection, "activity_description") ?? "Sem descricao").slice(0, 80)}</td>
                    <td className="rounded-r-lg px-3 py-4">
                      <Badge tone={collectionTone(collection.status, collection.sync_status)}>
                        {collection.status}
                      </Badge>
                    </td>
                  </motion.tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <aside className="brand-card min-w-0 p-5">
        {selected ? (
          <div className="grid gap-4">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <h2 className="text-lg font-semibold">Detalhe da coleta</h2>
                <p className="break-all text-sm text-[#64756F]">{selected.local_uuid}</p>
              </div>
              <Badge tone={collectionTone(selected.status, selected.sync_status)}>{selected.sync_status}</Badge>
            </div>
            <div className="brand-gradient rounded-lg p-4 text-white">
              <p className="text-sm text-white/70">Ficha tecnica</p>
              <p className="mt-1 break-words font-semibold">{projects.find((project) => project.id === selected.project_id)?.name || "Projeto"}</p>
              <p className="mt-2 text-sm text-white/72">{selected.collection_date || "Sem data"} | {selected.status}</p>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-lg bg-[#F4F8F6] p-3">
                <p className="text-xs text-[#64756F]">Latitude</p>
                <p className="font-semibold">{selected.latitude ?? "-"}</p>
              </div>
              <div className="rounded-lg bg-[#F4F8F6] p-3">
                <p className="text-xs text-[#64756F]">Longitude</p>
                <p className="font-semibold">{selected.longitude ?? "-"}</p>
              </div>
            </div>
            <div className="grid gap-2">
              {selected.answers.map((answer) => (
                <div key={answer.id ?? answer.field_key} className="min-w-0 rounded-lg bg-white p-3 shadow-sm ring-1 ring-[#DCE7E3]/70">
                  <p className="text-xs font-semibold uppercase text-[#64756F]">{answer.field_key}</p>
                  <p className="mt-1 break-words text-sm">{String(answer.answer_value ?? "-")}</p>
                </div>
              ))}
            </div>
            <div className="grid gap-2">
              <p className="text-sm font-semibold">Fotos</p>
              {selected.photos.length ? (
                selected.photos.map((photo) => (
                  <div key={photo.id ?? photo.file_path} className="flex min-w-0 items-center gap-3 rounded-lg bg-[#F4F8F6] p-3">
                    <Camera className="h-4 w-4 shrink-0 text-[#0A7354]" />
                    <span className="min-w-0 break-words text-sm">{photo.original_filename || photo.file_path}</span>
                  </div>
                ))
              ) : (
                <p className="text-sm text-[#64756F]">Sem fotos vinculadas.</p>
              )}
            </div>
            <div className="flex flex-wrap gap-2">
              <Button onClick={() => reviewMutation.mutate(selected.id)} disabled={reviewMutation.isPending}>
                <BadgeCheck className="h-4 w-4" />
                Revisar
              </Button>
              <a className="premium-btn inline-flex min-h-10 items-center gap-2 rounded-lg bg-[#EAF4F0] px-4 text-sm font-semibold text-[#0A7354]" href={exportUrl(`/collections/${selected.id}/pdf`)}>
                <FileText className="h-4 w-4" />
                PDF
              </a>
            </div>
          </div>
        ) : (
          <EmptyState icon={Archive} title="Selecione uma coleta" detail="O detalhe abre em painel lateral com respostas, fotos, mapa e historico." />
        )}
      </aside>
    </div>
  );
}

function CollectionMap({ collections, projects, compact = false }: { collections: Collection[]; projects: Project[]; compact?: boolean }) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const leafletRef = useRef<L.Map | null>(null);
  const markerLayerRef = useRef<L.LayerGroup | null>(null);
  const validCollections = useMemo(
    () => collections.filter((item) => item.latitude !== null && item.latitude !== undefined && item.longitude !== null && item.longitude !== undefined),
    [collections],
  );

  useEffect(() => {
    if (!mapRef.current || leafletRef.current) return;
    leafletRef.current = L.map(mapRef.current, { zoomControl: false }).setView([-20.383, -43.503], 10);
    L.control.zoom({ position: "bottomright" }).addTo(leafletRef.current);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap",
    }).addTo(leafletRef.current);
    markerLayerRef.current = L.layerGroup().addTo(leafletRef.current);
  }, []);

  useEffect(() => {
    const map = leafletRef.current;
    const layer = markerLayerRef.current;
    if (!map || !layer) return;
    layer.clearLayers();
    validCollections.forEach((collection) => {
      const toneClass =
        collection.status === "reviewed"
          ? "reviewed"
          : collectionTone(collection.status, collection.sync_status) === "red"
            ? "error"
            : collectionTone(collection.status, collection.sync_status) === "amber"
              ? "pending"
              : "";
      const icon = L.divIcon({
        className: "",
        html: `<div class="brandt-marker ${toneClass}"></div>`,
        iconSize: [18, 18],
      });
      const marker = L.marker([Number(collection.latitude), Number(collection.longitude)], { icon }).bindPopup(
        `<strong>${projects.find((project) => project.id === collection.project_id)?.name ?? "Projeto"}</strong><br/><span>${collection.status}</span><br/>${collection.collection_date ?? ""}<br/>${String(
          getAnswer(collection, "activity_description") ?? "",
        ).slice(0, 120)}`,
      );
      marker.addTo(layer);
    });
    if (validCollections.length) {
      const bounds = L.latLngBounds(validCollections.map((item) => [Number(item.latitude), Number(item.longitude)]));
      map.fitBounds(bounds, { padding: [24, 24], maxZoom: 15 });
    }
  }, [collections, projects, validCollections]);

  return (
    <section className="brand-card min-w-0 p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold">Mapa de coletas</h2>
          <p className="text-sm text-[#64756F]">Marcadores personalizados por status, popup premium e legenda Brandt.</p>
        </div>
        <Badge tone="green">{validCollections.length} pontos</Badge>
      </div>
      <div className={cx("grid min-w-0 gap-4", compact ? "" : "xl:grid-cols-[minmax(220px,280px)_minmax(0,1fr)]")}>
        {!compact && (
          <aside className="min-w-0 rounded-lg border border-[#DCE7E3] bg-[#F8FBFA] p-4">
            <p className="text-sm font-bold text-[#10231F]">Filtros visuais</p>
            <div className="mt-3 grid gap-2 text-sm text-[#64756F]">
              {[
                ["Normal", "bg-[#0A7354]"],
                ["Revisada", "bg-[#0F486E]"],
                ["Pendente", "bg-[#D8A23F]"],
                ["Erro/conflito", "bg-[#A23A35]"],
              ].map(([label, color]) => (
                <div key={label} className="flex items-center gap-2">
                  <span className={cx("h-3 w-3 rounded-full", color)} />
                  {label}
                </div>
              ))}
            </div>
          </aside>
        )}
        <div className={cx("min-w-0 overflow-hidden rounded-lg border border-[#DCE7E3]", compact ? "h-[360px]" : "h-[620px]")}>
          <div ref={mapRef} className="h-full w-full" />
        </div>
      </div>
    </section>
  );
}

function App() {
  const token = useAuthStore((state) => state.token);
  const [view, setView] = useState<View>("dashboard");
  const [toasts, setToasts] = useState<Toast[]>([]);
  const addToast = (toast: Omit<Toast, "id">) => {
    const id = Date.now();
    setToasts((current) => [...current, { ...toast, id }]);
    window.setTimeout(() => setToasts((current) => current.filter((item) => item.id !== id)), 4200);
  };

  const meQuery = useQuery({ queryKey: ["me"], queryFn: getMe, enabled: Boolean(token) });
  const dataQueries = useQueries({
    queries: [
      { queryKey: ["projects"], queryFn: getProjects, enabled: Boolean(token) },
      { queryKey: ["users"], queryFn: getUsers, enabled: Boolean(token && meQuery.data?.role.name === "admin") },
      { queryKey: ["forms"], queryFn: getForms, enabled: Boolean(token) },
      { queryKey: ["collections"], queryFn: getCollections, enabled: Boolean(token) },
    ],
  });
  const [projectsQuery, usersQuery, formsQuery, collectionsQuery] = dataQueries;
  const projects = (projectsQuery.data ?? []) as Project[];
  const users = (usersQuery.data ?? []) as User[];
  const forms = (formsQuery.data ?? []) as DynamicForm[];
  const collections = (collectionsQuery.data ?? []) as Collection[];

  const loading = useMemo(
    () => Boolean(token && (meQuery.isLoading || projectsQuery.isLoading || formsQuery.isLoading || collectionsQuery.isLoading)),
    [token, meQuery.isLoading, projectsQuery.isLoading, formsQuery.isLoading, collectionsQuery.isLoading],
  );

  if (!token) return <><LoginScreen onToast={addToast} /><Toasts items={toasts} /></>;
  if (meQuery.isError) return <><LoginScreen onToast={addToast} /><Toasts items={toasts} /></>;
  if (!meQuery.data || loading) {
    return (
      <main className="grid min-h-screen place-items-center bg-[#f4f1ea]">
        <div className="text-center">
          <Loader2 className="mx-auto h-8 w-8 animate-spin text-[#2f6f5e]" />
          <p className="mt-3 text-sm font-semibold text-[#617169]">Carregando dados do sistema</p>
        </div>
      </main>
    );
  }

  return (
    <>
      <Shell view={view} setView={setView} me={meQuery.data}>
        {view === "dashboard" && <Dashboard projects={projects} collections={collections} forms={forms} />}
        {view === "users" && <UsersView users={users} projects={projects} forms={forms} onToast={addToast} />}
        {view === "projects" && <ProjectsView projects={projects} onToast={addToast} />}
        {view === "forms" && <FormsView forms={forms} projects={projects} onToast={addToast} />}
        {view === "collections" && <CollectionsView collections={collections} projects={projects} forms={forms} onToast={addToast} />}
        {view === "map" && <CollectionMap collections={collections} projects={projects} />}
      </Shell>
      <Toasts items={toasts} />
    </>
  );
}

export default App;
