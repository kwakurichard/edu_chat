-- Create subjects table
create table if not exists public.subjects (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create topics table
create table if not exists public.topics (
  id uuid primary key default uuid_generate_v4(),
  subject_id uuid references public.subjects(id) on delete cascade not null,
  name text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(subject_id, name)
);

-- Create quiz_sessions table
create table if not exists public.quiz_sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null,
  topic_id uuid references public.topics(id) on delete set null,
  topic_name text not null,
  score integer default 0,
  total_questions integer default 0,
  completed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create quiz_answers table
create table if not exists public.quiz_answers (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid references public.quiz_sessions(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  question_text text not null,
  user_answer text,
  correct_answer text,
  is_correct boolean not null,
  llm_feedback text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Add Row Level Security (RLS) policies
alter table public.subjects enable row level security;
alter table public.topics enable row level security;
alter table public.quiz_sessions enable row level security;
alter table public.quiz_answers enable row level security;

-- Everyone can read subjects and topics
create policy "Subjects are viewable by everyone" on public.subjects
  for select using (true);

create policy "Topics are viewable by everyone" on public.topics
  for select using (true);

-- Users can only see their own quiz sessions and answers
create policy "Users can view their own quiz sessions" on public.quiz_sessions
  for select using (auth.uid() = user_id);

create policy "Users can insert their own quiz sessions" on public.quiz_sessions
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own quiz sessions" on public.quiz_sessions
  for update using (auth.uid() = user_id);

create policy "Users can view their own quiz answers" on public.quiz_answers
  for select using (auth.uid() = user_id);

create policy "Users can insert their own quiz answers" on public.quiz_answers
  for insert with check (auth.uid() = user_id);

-- Insert some sample subjects
insert into public.subjects (name) values
  ('Mathematics'),
  ('Science'),
  ('History'),
  ('Literature')
on conflict (name) do nothing;
