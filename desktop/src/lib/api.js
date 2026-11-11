// Cliente da API do All Love (a mesma usada pelo app mobile).
// Para usar outro servidor: crie desktop/.env com VITE_API_URL=http://endereco:3000
export const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

let token = localStorage.getItem('token');

export const isLoggedIn = () => !!token;

export function setToken(t) {
  token = t;
  if (t) localStorage.setItem('token', t);
  else localStorage.removeItem('token');
}

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

/** Chamada genérica: api('GET', '/feed') ou api('POST', '/dogs', {...}) */
export async function api(method, path, body) {
  let res;
  try {
    res = await fetch(`${API_URL}/api${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError('Não foi possível conectar ao servidor', 0);
  }
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    if (res.status === 401) setToken(null);
    throw new ApiError(data?.error ?? `Erro ${res.status}`, res.status);
  }
  return data;
}

/** Envia uma imagem (File) e devolve o caminho no servidor. */
export async function upload(file) {
  const form = new FormData();
  form.append('file', file);
  const res = await fetch(`${API_URL}/api/uploads`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const data = await res.json();
  if (!res.ok) throw new ApiError(data.error, res.status);
  return data.url;
}

/** Abre um link no navegador padrão (no Tauri usa o plugin opener). */
export async function openExternal(url) {
  if (window.__TAURI_INTERNALS__) {
    const { openUrl } = await import('@tauri-apps/plugin-opener');
    return openUrl(url);
  }
  window.open(url, '_blank', 'noreferrer');
}

export const imageUrl = (path) => (path ? `${API_URL}${path}` : null);

/** Endereço pelo CEP (ViaCEP). */
export async function lookupCep(cep) {
  const digits = cep.replace(/\D/g, '');
  if (digits.length !== 8) return null;
  try {
    const data = await (await fetch(`https://viacep.com.br/ws/${digits}/json/`)).json();
    return data.erro ? null : data;
  } catch {
    return null;
  }
}

// ---------- textos e formatação ----------

export const temperaments = {
  calmo: 'Calmo / mansinho',
  brincalhao: 'Brincalhão',
  timido: 'Tímido',
  agressivo: 'Agressivo',
};
export const sexes = { macho: 'Macho', femea: 'Fêmea' };
export const placeKinds = { parque: 'Parque', praca: 'Praça', ponto_encontro: 'Ponto de encontro' };
export const vaccineNames = ['V8', 'V10', 'Antirrábica', 'Gripe canina', 'Giárdia', 'Leishmaniose'];
export const reportReasons = {
  obscenidade: 'Obscenidade',
  perfil_falso: 'Perfil falso / se passando por outra pessoa',
  pede_localizacao: 'Pedindo localização ou dados pessoais',
  agressividade: 'Cão agressivo / mordeu',
  informacao_falsa: 'Informações falsas sobre o cão',
  processo_judicial: 'Dono em processo judicial envolvendo animais',
  outro: 'Outro',
};

export function formatDate(iso) {
  if (!iso || iso.length < 10) return iso ?? '';
  const [y, m, d] = iso.slice(0, 10).split('-');
  return `${d}/${m}/${y}`;
}

export function formatDistance(m) {
  if (m < 1000) return `${m} m`;
  const km = m / 1000;
  return Number.isInteger(km) ? `${km} km` : `${km.toFixed(1)} km`;
}

export const ageText = (y) => (y === 0 ? 'Filhote' : y === 1 ? '1 ano' : `${y} anos`);

export function vaccineText(s) {
  if (s.up_to_date) return 'Vacinação em dia';
  return [
    s.overdue.length ? `Atrasadas: ${s.overdue.join(', ')}` : null,
    s.missing.length ? `Faltando: ${s.missing.join(', ')}` : null,
  ]
    .filter(Boolean)
    .join(' • ');
}

export const today = () => new Date().toISOString().slice(0, 10);
