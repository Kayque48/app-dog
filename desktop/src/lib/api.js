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

/** Fotos enviadas ficam em "/uploads/..."; as de exemplo já vêm com a URL completa (Unsplash). */
export const imageUrl = (path) => (!path ? null : path.startsWith('http') ? path : `${API_URL}${path}`);

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

// ---------- eventos ----------

export const eventKinds = {
  desfile: { label: 'Desfile', icon: 'styler' },
  corrida: { label: 'Corrida', icon: 'sprint' },
  festa: { label: 'Festa', icon: 'celebration' },
  encontro: { label: 'Encontro', icon: 'groups' },
  concurso: { label: 'Concurso', icon: 'emoji_events' },
  adocao: { label: 'Adoção', icon: 'volunteer_activism' },
  competicao: { label: 'Competição', icon: 'fitness_center' },
};

const WEEK = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
const MONTH = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];

/** "2026-11-14 15:00" -> { week: 'SÁB', day: '14', month: 'NOV', time: '15:00', countdown: 'em 3 dias' } */
export function eventDate(startsAt) {
  const d = new Date(startsAt.replace(' ', 'T'));
  const days = Math.round((new Date(d.toDateString()) - new Date(new Date().toDateString())) / 86_400_000);
  const countdown = days <= 0 ? 'hoje!' : days === 1 ? 'amanhã' : `em ${days} dias`;
  return {
    week: WEEK[d.getDay()],
    day: String(d.getDate()).padStart(2, '0'),
    month: MONTH[d.getMonth()],
    time: startsAt.slice(11, 16),
    countdown,
    soon: days <= 2,
  };
}

// ---------- perfil, carteira, serviços e loja ----------

export const activityLevels = { baixo: 'Sossegado', medio: 'Moderado', alto: 'Elétrico' };
export const lookingFor = { amizade: 'Amizade', cruzamento: 'Cruzamento', ambos: 'Amizade e cruzamento' };
export const docKinds = { pedigree: 'Pedigree', exame: 'Exame', rg: 'RG animal', receita: 'Receita', outro: 'Outro' };
export const providerKinds = {
  veterinario: { label: 'Veterinários', icon: 'medical_services' },
  banho_tosa: { label: 'Banho e tosa', icon: 'shower' },
  pet_shop: { label: 'Pet shops', icon: 'storefront' },
  adestrador: { label: 'Adestradores', icon: 'school' },
  passeador: { label: 'Passeadores', icon: 'directions_walk' },
  hotel: { label: 'Hotéis e creches', icon: 'hotel' },
  criador: { label: 'Criadores', icon: 'workspace_premium' },
  adocao: { label: 'Adoção', icon: 'volunteer_activism' },
};
export const productCategories = {
  roupas: { label: 'Roupas', icon: 'checkroom' },
  alimentos: { label: 'Alimentos', icon: 'restaurant' },
  brinquedos: { label: 'Brinquedos', icon: 'sports_baseball' },
  acessorios: { label: 'Acessórios', icon: 'pets' },
  higiene: { label: 'Higiene', icon: 'soap' },
};

export const formatPrice = (cents) => (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

/** Link de WhatsApp para um telefone brasileiro com uma mensagem pronta. */
export const whatsapp = (phone, text = '') => `https://wa.me/55${phone}${text ? `?text=${encodeURIComponent(text)}` : ''}`;

/** "Au au!" sintetizado com a Web Audio API (não precisa de arquivo de som). */
export function playBark() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const woof = (start) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();
      osc.type = 'sawtooth';
      filter.type = 'lowpass';
      filter.frequency.value = 1400;
      osc.frequency.setValueAtTime(520, start);
      osc.frequency.exponentialRampToValueAtTime(180, start + 0.18);
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.5, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.22);
      osc.connect(filter).connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + 0.25);
    };
    woof(ctx.currentTime);
    woof(ctx.currentTime + 0.32);
  } catch {
    /* navegador sem áudio: segue sem som */
  }
}
