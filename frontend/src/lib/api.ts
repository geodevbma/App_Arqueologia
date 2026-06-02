import axios from "axios";
import { create } from "zustand";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? "http://localhost:8000",
});

type AuthState = {
  token: string | null;
  setToken: (token: string | null) => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  token: localStorage.getItem("brandt_token"),
  setToken: (token) => {
    if (token) {
      localStorage.setItem("brandt_token", token);
    } else {
      localStorage.removeItem("brandt_token");
    }
    set({ token });
  },
}));

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export type Role = {
  id: string;
  name: "admin" | "coordinator" | "archaeologist" | "viewer" | string;
  description?: string;
};

export type User = {
  id: string;
  name: string;
  email: string;
  role: Role;
  is_active: boolean;
  project_ids: string[];
  form_ids: string[];
};

export type Project = {
  id: string;
  name: string;
  code?: string | null;
  description?: string | null;
  status: string;
  start_date?: string | null;
  end_date?: string | null;
};

export type Section = {
  id: string;
  project_id: string;
  name: string;
  order_index: number;
};

export type WorkPoint = {
  id: string;
  section_id: string;
  name: string;
  order_index: number;
  is_active: boolean;
};

export type FormField = {
  id?: string;
  form_id?: string;
  version?: number;
  label: string;
  field_key: string;
  field_type: string;
  is_required: boolean;
  order_index: number;
  options?: unknown;
  conditional_logic?: unknown;
};

export type DynamicForm = {
  id: string;
  project_id: string;
  name: string;
  description?: string | null;
  status: string;
  current_version: number;
  fields: FormField[];
};

export type CollectionAnswer = {
  id?: string;
  field_key: string;
  answer_value: unknown;
};

export type CollectionPhoto = {
  id?: string;
  photo_type: string;
  file_path: string;
  original_filename?: string | null;
};

export type Collection = {
  id: string;
  local_uuid: string;
  server_uuid?: string | null;
  project_id: string;
  form_id: string;
  form_version: number;
  section_id?: string | null;
  work_point_id?: string | null;
  work_point_other?: string | null;
  user_id: string;
  collection_date?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  gps_accuracy?: number | null;
  coordinate_was_edited: boolean;
  status: string;
  sync_status: string;
  synced_at?: string | null;
  answers: CollectionAnswer[];
  photos: CollectionPhoto[];
};

export async function login(email: string, password: string) {
  const { data } = await api.post<{ access_token: string }>("/auth/login", { email, password });
  return data.access_token;
}

export async function getMe() {
  const { data } = await api.get<User>("/auth/me");
  return data;
}

export async function getProjects() {
  const { data } = await api.get<Project[]>("/projects");
  return data;
}

export async function getUsers() {
  const { data } = await api.get<User[]>("/users");
  return data;
}

export async function getForms() {
  const { data } = await api.get<DynamicForm[]>("/forms");
  return data;
}

export async function getCollections() {
  const { data } = await api.get<Collection[]>("/collections");
  return data;
}

export async function getSections(projectId: string) {
  const { data } = await api.get<Section[]>(`/projects/${projectId}/sections`);
  return data;
}

export async function getWorkPoints(sectionId: string) {
  const { data } = await api.get<WorkPoint[]>(`/sections/${sectionId}/work-points`);
  return data;
}

export function exportUrl(path: string) {
  return `${api.defaults.baseURL}${path}`;
}
