local hulib = require "hulib"

local M = {}

-- 常量定义
M.GAME_PLAYER                       = 4                                 --游戏人数
M.MAX_WEAVE                         = 4                                 --最大组合
M.MAX_INDEX                         = 34                                --最大索引
M.MAX_COUNT                         = 14                                --最大数目
M.MAX_REPERTORY                     = 108                               --最大库
M.HEAP_FULL_COUNT                   = 26                                --堆立全牌
M.INVALID_CHAIR                     = 0xFFFF                            --无效数值

--动作标志
M.WIK_NULL		= 0x00								--没有类型
M.WIK_LEFT		= 0x01								--左吃类型
M.WIK_CENTER	= 0x02								--中吃类型
M.WIK_RIGHT		= 0x04								--右吃类型
M.WIK_PENG		= 0x08								--碰牌类型
M.WIK_GANG		= 0x10								--杠牌类型
M.WIK_LISTEN	= 0x20								--吃牌类型
M.WIK_CHI_HU	= 0x40								--吃胡类型
M.WIK_FILL		= 0x80								--补杠类型

--胡牌定义
M.CHK_PENG_PENG		    = 0x00010000							--碰碰胡牌
M.CHK_QI_XIAO_DUI		= 0x00020000							--七小对牌
M.CHK_SHI_SAN_YAO		= 0x00040000							--十三幺牌


M.MASK_VALUE = 0x0F
M.MASK_COLOR = 0xF0

M.CARD_DEFINE = {
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, -- 万
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, -- 筒
    0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, -- 条
    0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,             -- 东南西北中发白
    0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,       -- 春夏秋冬梅兰竹菊
}

-- 扑克数据
M.CARD_DATA_ARRAY = {
	0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,						--万子
	0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,						--万子
	0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,						--万子
	0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,						--万子

	0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,						--索子
	0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,						--索子
	0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,						--索子
	0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,						--索子

	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,						--同子
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,						--同子
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,						--同子
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,						--同子

    --东 南   西   北   红中 发财 白板
    0x31,0x32,0x33,0x34,0x35,0x36,0x37,                                 --番字
    0x31,0x32,0x33,0x34,0x35,0x36,0x37,                                 --番字
    0x31,0x32,0x33,0x34,0x35,0x36,0x37,                                 --番字
    0x31,0x32,0x33,0x34,0x35,0x36,0x37,                                 --番字

    --春 夏   秋   冬   梅   兰   竹   菊
    0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F                             --花子
}

function M.get_card_str(index)
    if index >= 1 and index <= 9 then
        return index .. "万"
    elseif index >= 10 and index <= 18 then
        return (index - 9) .. "筒"
    elseif index >= 19 and index <= 27 then
        return (index - 18) .. "条"
    end

    local t = {"东","西","南","北","中","发","白","春","夏","秋","冬","梅","兰","竹","菊"}
    return t[index - 27]
end

function M.print(tbl)
    local str = ""
    local card_str
    for i=1,42 do
        if tbl[i] > 0 then
            card_str = M.get_card_str(i)
        end

        if tbl[i] == 1 then
            str = str .. card_str
        elseif tbl[i] == 2 then
            str = str .. card_str .. card_str
        elseif tbl[i] == 3 then
            str = str .. card_str .. card_str .. card_str
        elseif tbl[i] == 4 then
            str = str .. card_str .. card_str .. card_str .. card_str
        end
    end

    print(str)
end

-- 有效判断
function M.is_valid_card(card)
    local value = M.get_card_value(card)
    local color = M.get_card_color(card)
    return (((value>=1) and (value<=9) and (color<=2)) 
            or ((value>=1) and (value<=7) and (color==3)) 
            or ((value>=1) and (value<=8) and (color==4)))
end

function M.get_card_color(card)
    return card & M.MASK_VALUE
end

function M.get_card_value(card)
    return (card & MASK_COLOR) >> 4
end

function M.get_index_color(index)
    return math.ceil(index / 9) - 1
end

function M.get_index_value(index)
    return (index-1) % 9 + 1
end

function M.index2card(index)
    return (M.get_index_color(index) << 4) | M.get_index_value(index)
end

function M.card2index(card)
    return M.get_card_color(card) * 9 + M.get_card_value(card)
end

function M.index2card_array(index)
    local card = {}
    for i, v in ipairs(index) do 
        for j = 1, v do
            card[#card+1] = M.index2card(i)
        end 
    end 
    return card
end

function M.card2index_array(card_data)
    local card_index = {}
    for i = 1, #M.CARD_DEFINE do
        card_index[i] = 0
    end
    for _, v in ipairs(card_data) do 
        card_index[M.card2index(v)] = (card_index[M.card2index(v)] and card_index[M.card2index(v)] + 1) or 1
    end 
    return card_index
end

-- 创建一幅牌,牌里存的不是牌本身，而是牌的序号
function M.create(zi)
    local t = {}

    local num = 3*9

    if zi then
        num = num + 7
    end

    for i=1,num do
        for _=1,4 do
            table.insert(t, i)
        end
    end

    return t
end

-- 洗牌
function M.shuffle(t)
    for i=#t,2,-1 do
        local tmp = t[i]
        local index = math.random(1, i - 1)
        t[i] = t[index]
        t[index] = tmp
    end
end

function M.analyse_gang_card(card_index, weave_item)
    local action_mask = M.WIK_NULL
    for i, v in ipairs(card_index) do
        if v == 4 then
            action_mask = action_mask | M.WIK_GANG
        end
    end

    if not weave_item then 
        return action_mask
    end

    for i, v in ipairs(weave_item) do
        if v.weave_type == M.WIK_PENG then
            if card_index[M.card2index(v.center_card)] == 1 then
                action_mask = action_mask | M.WIK_FILL
                return action_mask
            end
        end
    end
    return action_mask
end

function M.analyse_chihu_card(card_index, weave_item, current_card)
    local chihu_type = M.WIK_NULL

    -- 插入
    if current_card and current_card ~= 0 then
        card_index[M.card2index(current_card)] = card_index[M.card2index(current_card)] + 1
    end

    if hulib.get_hu_info(card_index) then
        local chihu_type = M.WIK_PING_HU
    end

    -- 删除
    if current_card and current_card ~= 0 then
        card_index[M.card2index(current_card)] = card_index[M.card2index(current_card)] - 1
    end

    return chihu_type
end

function M.remove_card(card_index, card_data)
    if not M.is_valid_card(card_data) then
        return false
    end

    local remove_index = M.card2index(card_data)
    if card_index[remove_index] <= 0 then
        return false
    end

    card_index[remove_index] = card_index[remove_index] - 1

    return true
end


function M.remove_card_array(card_index, card_data)
    for i, v in ipairs(card_data) do
        if not M.remove_card(card_index, v) then
            return false
        end
    end
end

function M.get_user_action_rank(user_action)
    if (user_action & M.WIK_CHI_HU) ~= 0 then
        return 4
    end
    if (user_action & (M.WIK_GANG | M.WIK_FILL)) ~= 0 then
        return 3
    end
    if (user_action & M.WIK_PENG) ~= 0 then
        return 2
    end
    if (user_action & (M.WIK_RIGHT | M.WIK_CENTER | M.WIK_LEFT)) ~= 0 then
        return 1
    end

    return 0
end

function M.estimate_eat_card(card_index, current_card)
    -- 番子无连
    if current_card >= 0x31 then 
        return M.WIK_NULL
    end

    local excursion = {0 ,1 ,2}
    local item_type = {M.WIK_LEFT, M.WIK_CENTER, M.WIK_RIGHT}

    -- 吃牌判断
    local eat_type = 0
    local first_index = 1
    local current_index = M.card2index(current_card)
    for i = 1, #item_type do
        local value_index = (current_index - 1) % 9 + 1
        if (value_index >= excursion[i] + 1) and ((value_index - excursion[i]) <= 7) then
            -- 吃牌判断
            repeat

                first_index = current_index - excursion[i]

                if current_index ~= first_index and card_index[first_index] == 0 then
                    break
                end

                if current_index ~= first_index + 1 and card_index[first_index + 1] == 0 then
                    break
                end

                if current_index ~= first_index + 2 and card_index[first_index + 2] == 0 then
                    break
                end

                -- 设置类型
                eat_type = eat_type | item_type[i]

            until true
        end
    end

    return eat_type
end

function M.estimate_peng_card(card_index, current_card)
	--碰牌判断
    return card_index[M.card2index(current_card)] >= 2 and M.WIK_PENG or WIK_NULL
end

function M.estimate_gang_card(card_index, current_card)
	--杠牌判断
    return card_index[M.card2index(current_card)] == 2 and M.WIK_GANG or WIK_NULL
end

return M
