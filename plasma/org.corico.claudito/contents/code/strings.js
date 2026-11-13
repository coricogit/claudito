.pragma library

var STRINGS = {
  en: {
    wake: "Hi!",
    thinking: "Thinking…",
    build: "Editing %1",
    buildPlain: "Editing files",
    terminal: "Terminal: %1",
    terminalPlain: "In the terminal",
    search: "Reading %1",
    searchPlain: "Investigating the code",
    explore: "Searching the web: %1",
    explorePlain: "Exploring the web",
    lead: "Leading agents: %1",
    leadPlain: "Leading agents",
    plan: "Making a plan",
    create: "Creating: %1",
    createPlain: "Creating something",
    work: "Using %1",
    workPlain: "Working",
    waiting: "Waiting for you!",
    oops: "Oops, that failed",
    done: "Done!",
    idle: "Ready",
    sleep: "Zzz…"
  },
  es: {
    wake: "¡Hola!",
    thinking: "Pensando…",
    build: "Editando %1",
    buildPlain: "Editando archivos",
    terminal: "Terminal: %1",
    terminalPlain: "En la terminal",
    search: "Leyendo %1",
    searchPlain: "Investigando el código",
    explore: "Buscando en la web: %1",
    explorePlain: "Explorando la web",
    lead: "Dirigiendo agentes: %1",
    leadPlain: "Dirigiendo agentes",
    plan: "Haciendo un plan",
    create: "Creando: %1",
    createPlain: "Creando algo",
    work: "Usando %1",
    workPlain: "Trabajando",
    waiting: "¡Te necesito!",
    oops: "Uy, eso falló",
    done: "¡Listo!",
    idle: "Listo para ayudar",
    sleep: "Zzz…"
  }
}

function t(key) {
  var lang = Qt.locale().name.split("_")[0]
  var table = STRINGS[lang] || STRINGS.en
  return table[key] || STRINGS.en[key] || key
}
