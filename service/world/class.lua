local M = {}

function M.Class(base)
    local c
    c = {
        _base = base,
        __index = function(t,k)
            local v = c[k]
            if v then
                return v
            end

            local b = c._base
            while b do
                local v = b[k]
                if v then
                    return v
                end
                b = b._base
            end
        end
    }
    return c
end

return M