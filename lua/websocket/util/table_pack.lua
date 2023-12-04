local function pack_table(...)
  return { n = select("#", ...), ... }
end

return pack_table
