.pragma library

// Which hat Claudito wears for each mode ("" = no hat).
function hatFor(mode) {
  switch (mode) {
  case "thinking": return "beanie"
  case "build": return "hardhat"
  case "terminal": return "miner"
  case "search": return "detective"
  case "explore": return "explorer"
  case "lead": return "captain"
  case "plan": return "wizard"
  case "create": return "beret"
  case "done": return "party"
  case "sleep": return "nightcap"
  default: return ""
  }
}
