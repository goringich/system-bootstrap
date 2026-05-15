const fs = require('fs');
const path = require('path');

const sourceDir = '/home/goringich/Desktop/Obsidian/Православие/Google Keep/Заметки/Жития';
const outputDir = path.join(sourceDir, 'По месяцам');

const monthForms = {
  'января': 'Январь',
  'февраля': 'Февраль',
  'марта': 'Март',
  'апреля': 'Апрель',
  'мая': 'Май',
  'июня': 'Июнь',
  'июля': 'Июль',
  'августа': 'Август',
  'сентября': 'Сентябрь',
  'октября': 'Октябрь',
  'ноября': 'Ноябрь',
  'декабря': 'Декабрь',
};

const monthPattern = Object.keys(monthForms).join('|');

function normalizeSpaces(value) {
  return value.replace(/\s+/g, ' ').trim();
}

function slugDay(day) {
  return String(day).padStart(2, '0');
}

function sanitizeName(value, limit = 110) {
  const sanitized = normalizeSpaces(value)
    .replace(/[\\/:*?"<>|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (sanitized.length <= limit) {
    return sanitized;
  }
  return sanitized.slice(0, limit).trimEnd();
}

function cleanDetail(value) {
  return normalizeSpaces(
    value
      .replace(/\[\[[^\]]+\]\]/g, '')
      .replace(/[()]+/g, ' ')
      .replace(/\s+-\s+/g, ' - ')
  );
}

function truncateSentence(value, limit = 260) {
  if (value.length <= limit) {
    return value;
  }
  return `${value.slice(0, limit - 1).trimEnd()}…`;
}

function titleToLead(title) {
  const cleaned = normalizeSpaces(title).replace(/[.)\s]+$/g, '');
  if (/^Житие /u.test(cleaned)) {
    return cleaned.replace(/^Житие /u, 'житие ');
  }
  if (/^Память /u.test(cleaned)) {
    return cleaned.replace(/^Память /u, 'память ');
  }
  if (/^Страдание /u.test(cleaned)) {
    return cleaned.replace(/^Страдание /u, 'страдание ');
  }
  if (/^Собор /u.test(cleaned)) {
    return cleaned.replace(/^Собор /u, 'собор ');
  }
  if (/^Слово /u.test(cleaned)) {
    return cleaned.replace(/^Слово /u, 'слово ');
  }
  return cleaned.charAt(0).toLowerCase() + cleaned.slice(1);
}

function makeSummary(title, detail) {
  if (!detail || !cleanDetail(detail)) {
    return `Кратко: В исходной заметке отмечено только ${titleToLead(title)} без дополнительных пометок.`;
  }

  const cleaned = cleanDetail(detail)
    .replace(/\s*,\s*/g, ', ')
    .replace(/\s*;\s*/g, '; ')
    .replace(/\s*\.\s*/g, '. ');

  const fragments = cleaned
    .split(/(?<=[.;!?])\s+|;\s+/)
    .map((item) => normalizeSpaces(item))
    .filter((item) => item.length >= 18);

  if (fragments.length === 0) {
    if (cleaned.length < 20) {
      return `Кратко: ${cleaned}. Это почти всё, что было отмечено в исходной заметке.`;
    }
    return `Кратко: ${truncateSentence(cleaned)}.`;
  }

  const picked = [];
  for (const fragment of fragments) {
    picked.push(fragment.replace(/[.)\s]+$/g, ''));
    if (picked.join('. ').length >= 220 || picked.length >= 2) {
      break;
    }
  }

  const summary = truncateSentence(picked.join('. ')).replace(/^[.,;\s]+|[.,;\s]+$/g, '');
  if (!summary) {
    return `Кратко: В исходной заметке отмечено только ${titleToLead(title)} без дополнительных пометок.`;
  }
  if (summary.length < 20) {
    return `Кратко: ${summary}. Это почти всё, что было отмечено в исходной заметке.`;
  }
  return `Кратко: ${summary}.`;
}

function parseBlock(block) {
  const trimmed = normalizeSpaces(block.replace(/^\-\s*/, ''));
  if (!trimmed || trimmed.startsWith('[[')) {
    return null;
  }

  const patterns = [
    /^(?:Память\s+)?(\d{1,2})\s+([А-Яа-яё]+)(?:\s*\([^)]*\))?\s*-\s*(.+)$/u,
    /^(\d{1,2})\s+([А-Яа-яё]+)\s*-\s*(.+)$/u,
    /^(\d{1,2})\s+([А-Яа-яё]+)\s+(.+)$/u,
    /^(.+?)\s+(\d{1,2})\s+([А-Яа-яё]+)(?:\s*\([^)]*\))?$/u,
  ];

  for (const pattern of patterns) {
    const match = trimmed.match(pattern);
    if (!match) {
      continue;
    }

    let day;
    let month;
    let title;

    if (pattern === patterns[3]) {
      title = normalizeSpaces(match[1]);
      day = Number(match[2]);
      month = match[3].toLowerCase();
    } else {
      day = Number(match[1]);
      month = match[2].toLowerCase();
      title = normalizeSpaces(match[3]);
    }

    const monthName = monthForms[month];
    if (!monthName) {
      return null;
    }

    let parsedTitle = title;
    let parsedDetail = '';
    const parenIndex = title.indexOf('(');
    if (parenIndex >= 0) {
      parsedTitle = normalizeSpaces(title.slice(0, parenIndex));
      parsedDetail = normalizeSpaces(title.slice(parenIndex + 1).replace(/\)+$/g, ''));
    }

    return {
      day,
      month,
      monthName,
      title: parsedTitle.replace(/[.)\s-]+$/g, ''),
      detail: parsedDetail,
    };
  }

  return null;
}

function parseFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content
    .replace(new RegExp(`\\s*-\\s+(?=(?:Память\\s+)?\\d{1,2}\\s+(?:${monthPattern})(?:\\s*\\([^)]*\\))?\\s*-)`, 'gu'), '\n- ')
    .split(/\r?\n/);
  const blocks = [];
  let current = null;

  for (const line of lines) {
    if (
      current &&
      new RegExp(`^(?:Память\\s+)?\\d{1,2}\\s+(?:${monthPattern})(?:\\s*\\([^)]*\\))?\\s*-`, 'u').test(line.trim())
    ) {
      blocks.push(current.join('\n'));
      current = [`- ${line.trim()}`];
      continue;
    }

    if (/^\-\s/.test(line)) {
      if (current) {
        blocks.push(current.join('\n'));
      }
      current = [line];
      continue;
    }

    if (current) {
      if (/^###\s/.test(line)) {
        blocks.push(current.join('\n'));
        current = null;
        continue;
      }

      if (line.trim() === '') {
        current.push(line);
        continue;
      }

      current.push(line);
    }
  }

  if (current) {
    blocks.push(current.join('\n'));
  }

  const result = [];
  for (const block of blocks) {
    const dateMatches = block.match(new RegExp(`(?:Память\\s+)?\\d{1,2}\\s+(?:${monthPattern})`, 'gu')) || [];
    if (dateMatches.length > 1) {
      continue;
    }

    const parsed = parseBlock(block);
    if (!parsed) {
      continue;
    }

    if (!parsed.title || parsed.title === '-' || parsed.title.length < 3) {
      continue;
    }

    const body = block.replace(/^\-\s*/, '');
    const detailStart = body.indexOf('\n');
    const extraBody = detailStart >= 0 ? body.slice(detailStart + 1).trim() : '';
    const detail = normalizeSpaces([parsed.detail, extraBody].filter(Boolean).join(' '));

    result.push({
      ...parsed,
      detail,
      sourceName: path.basename(filePath, '.md'),
      sourcePath: filePath,
    });
  }

  return result;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function writeFile(filePath, content) {
  fs.writeFileSync(filePath, `${content.trim()}\n`, 'utf8');
}

function main() {
  const files = fs.readdirSync(sourceDir)
    .filter((name) => name.endsWith('.md'))
    .map((name) => path.join(sourceDir, name));

  const entries = [];
  const seen = new Set();
  for (const file of files) {
    for (const entry of parseFile(file)) {
      if (/[,\s]Х$/u.test(entry.title)) {
        continue;
      }
      const key = `${entry.monthName}|${entry.day}|${entry.title}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      entries.push(entry);
    }
  }

  const groupedByMonth = new Map();
  for (const entry of entries) {
    if (!groupedByMonth.has(entry.monthName)) {
      groupedByMonth.set(entry.monthName, []);
    }
    groupedByMonth.get(entry.monthName).push(entry);
  }

  ensureDir(outputDir);

  const summaryLines = [];
  const monthOrder = Object.values(monthForms);

  for (const monthName of monthOrder) {
    const monthEntries = (groupedByMonth.get(monthName) || []).sort((a, b) => {
      if (a.day !== b.day) {
        return a.day - b.day;
      }
      return a.title.localeCompare(b.title, 'ru');
    });

    if (monthEntries.length === 0) {
      continue;
    }

    const monthDir = path.join(outputDir, monthName);
    ensureDir(monthDir);

    const byDate = new Map();
    for (const entry of monthEntries) {
      const dateKey = `${slugDay(entry.day)} ${entry.month}`;
      if (!byDate.has(dateKey)) {
        byDate.set(dateKey, []);
      }
      byDate.get(dateKey).push(entry);
    }

    const monthLinks = [];
    for (const [dateKey, dateEntries] of [...byDate.entries()].sort((a, b) => a[0].localeCompare(b[0], 'ru'))) {
      const first = dateEntries[0];
      const dateTitle = `${slugDay(first.day)} ${first.month}`;

      if (dateEntries.length === 1) {
        const entry = dateEntries[0];
        const noteName = sanitizeName(`${dateTitle} — ${entry.title}`);
        const content = `
# ${entry.title}

- Дата: ${entry.day} ${entry.month}
- Месяц: [[${monthName}]]
- Источник: [[${entry.sourceName}]]

${makeSummary(entry.title, entry.detail)}
        `;
        writeFile(path.join(monthDir, `${noteName}.md`), content);
        monthLinks.push(`- [[${noteName}|${entry.day} ${entry.month}]]`);
      } else {
        const parentName = dateTitle;
        const childLinks = [];

        for (const entry of dateEntries) {
          const childName = sanitizeName(`${dateTitle} — ${entry.title}`);
          const content = `
# ${entry.title}

- Дата: [[${parentName}]]
- Месяц: [[${monthName}]]
- Источник: [[${entry.sourceName}]]

${makeSummary(entry.title, entry.detail)}
          `;
          writeFile(path.join(monthDir, `${childName}.md`), content);
          childLinks.push(`- [[${childName}]]`);
        }

        const parentContent = `
# ${first.day} ${first.month}

- Месяц: [[${monthName}]]

## Жития
${childLinks.join('\n')}
        `;
        writeFile(path.join(monthDir, `${parentName}.md`), parentContent);
        monthLinks.push(`- [[${parentName}|${first.day} ${first.month}]]`);
      }
    }

    const monthContent = `
# ${monthName}

## Даты
${monthLinks.join('\n')}
    `;
    writeFile(path.join(monthDir, `${monthName}.md`), monthContent);
    summaryLines.push(`- [[${monthName}/${monthName}|${monthName}]]`);
  }

  const rootContent = `
# Жития святых по месяцам

## Месяцы
${summaryLines.join('\n')}
  `;
  writeFile(path.join(outputDir, 'Жития святых по месяцам.md'), rootContent);

  console.log(JSON.stringify({
    entries: entries.length,
    months: summaryLines.length,
    outputDir,
  }, null, 2));
}

main();
