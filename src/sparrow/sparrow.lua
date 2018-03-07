local logic = require "logic"

local M = {}
M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init()
    -- 游戏变量
    self.sice_count = {0, 0, 0, 0}
    self.game_score = {0, 0, 0, 0}
    self.banker_user = logic.INVALID_CHAIR
    self.player_count = logic.GAME_PLAYER

    self.card_index = {}    -- create the matrix
    --for i = 1, logic.GAME_PLAYER do
        --self.card_index[i] = {} -- create a new row
        --for j = 1, logic.MAX_INDEX do
            --self.card_index[i][j] = 0
        --end
    --end

    self.trustee = {false, false, false, false}
    self.ready = {false, false, false, false}
    self.play_status = {false, false, false, false}

    -- 出牌信息
    self.out_card_data = 0
    self.out_card_count = 0
    self.out_card_user = logic.INVALID_CHAIR
    self.discard_count = 0
    self.discard_card = {}    -- create the matrix
    for i = 1, logic.GAME_PLAYER do
        self.discard_card[i] = {} -- create a new row
    end

    -- 发牌信息
    self.send_card_data = 0
    self.send_card_count = 0
    self.left_card_count = 0
    self.repertory_card = {}
    for i, v in ipairs(logic.CARD_DATA_ARRAY) do 
        self.repertory_card[i] = v   
    end

    -- 堆立信息
    self.heap_hand = logic.INVALID_CHAIR
    self.heap_tail = logic.INVALID_CHAIR
    self.heap_card_info = {}
    for i = 1, logic.GAME_PLAYER do
        self.heap_card_info [i] = {} 
        for j = 1, 2 do
            self.heap_card_info [i][j] = 0
        end
    end

    -- 运行变量
    self.provide_card = 0
    self.resume_user = logic.INVALID_CHAIR
    self.current_user = logic.INVALID_CHAIR
    self.provide_user = logic.INVALID_CHAIR

    -- 状态变量
    self.send_status = false
    self.gang_status = false
    self.enjoin_chihu = {false, false, false, false}
    self.enjoin_chipeng = {false, false, false, false}

    -- 用户状态
    self.response = {false, false, false, false}
    self.user_action = {0, 0, 0, 0}
    self.operate_card = {0, 0, 0, 0}
    self.perform_action = {0, 0, 0, 0}

    -- 组合扑克
    self.weave_item_array = {}
    self.weave_item_count = {0, 0, 0, 0}

    -- 结束信息
    self.chihu_card = 0
    self.chihu_mask = {0, 0, 0, 0}

    -- 胜利用户
    self.winuser = logic.INVALID_CHAIR
    self.room_owner = logic.INVALID_CHAIR

    -- 游戏局数
    self.game_status = false
    self.gamen_number = logic.INVALID_CHAIR		

    -- 分数
    self.cell_score = 0
    self.least_score = 0

    -- 用户
    self.player = {} 
end

function send_client(gate, uid, v)
    skynet.send(gate, "lua", "send_client", uid, v)
end

function M:send_table(chairid, msg)
    if chairid ~= logic.INVALID_CHAIR then
        for i, v in ipairs(self.player) do
            send_client(v.gate, uid, msg)
        end
    else 
        send_client(self.player[i].gate, self.player[i].profile.uid, msg)
    end
end

-- 发送操作
function M:send_operate_notify()
    -- 发送提示
    for i = 1, logic.GAME_PLAYER do
        if self.user_action[i] ~= logic.WIK_NULL then
            local msg = {
                cmd = "operate_notify",
                resume_user = self.resume_user,
                action_card = self.provide_card
                action_mask = self.user_action[i]
            }
            self:send_table(i, msg)
            -- TODO 超时
        end
    end
end

-- 游戏开始
function M:start() 
    for i = 1, logic.GAME_PLAYER do
        self.sice_count[i] = math.random(6)
    end

    -- 混乱扑克
    logic.shuffle(self.repertory_card)
    self.left_card_count = #self.repertory_card
    self.banker_user = ((self.sice_count[1] + self.sice_count[2]) - 1) % logic.GAME_PLAYER + 1

    -- 分发扑克
    for i = 1, logic.GAME_PLAYER do
        self.left_card_count =  self.left_card_count - (logic.MAX_COUNT - 1)
        local card_data = {}
        for j = 1, logic.MAX_COUNT - 1 do
            card_data[j] = self.repertory_card[self.left_card_count + i]
        end
        self.card_index[i] = logic.card2index_array(card_data)
    end

    -- 发送扑克
    self.send_card_count = self.send_card_data + 1
    self.send_card_data = self.repertory_card[self.left_card_count]
    self.left_card_count = self.left_card_count - 1;
    local card_count = self.card_index[self.banker_user][logic.card2index(self.send_card_data)]
    self.card_index[self.banker_user][logic.card2index(self.send_card_data)] = card_count + 1
    self.current_user = self.banker_user

    -- 杠牌判断
    self.user_action[self.banker_user] = logic.analyse_gang_card(self.card_index[self.banker_user])

    -- 胡牌判断 
    self.user_action[self.banker_user] = self.user_action[self.banker_user] | logic.analyse_chihu_card(self.card_index[self.banker_user])

    self.game_status = true

    local msg = {
       cmd = "start", 
       sice_count = {self.sice_count[1], self.sice_count[2], self.sice_count[3], self.sice_count[4]}, 
       banker_user = self.banker_user,
       current_user = self.current_user,
       heap_hand = self.heap_hand,
       heap_tail = self.heap_tail,
       left_card_count = self.left_card_count,
       gamen_number = self.gamen_number,
       player = self.player
    }

    --发送数据
    for i = 1, self.player_count do 
        msg.chairid = i
        msg.user_action = self.user_action[i]
        msg.card_data = logic.index2card_array.(self.card_index[i])
        msg.card_count = #msg.card_data
        self:send_table(i, msg)
    end

end

function M:over()
    self.gamen_number = self.game_number - 1
    local msg = {
        cmd = "over",
        left_user = logic.INVALID_CHAIR,
        win_user = self.win_user,
        provide_card = self.provide_card,
        provide_user = self.provide_user,
        game_number = self.gamen_number
    }

    msg.card_info = {}
    for i = i, logic.GAME_PLAYER do 
        local card_info = {
            chairid = i,
            card_data = logic.index2card_array(self.card_index[i])
            card_count = #card_data
            chihu_mask = self.chihu_mask[i]
            score = self.game_score[i]
        }
        msg.card_info[i] = card_info
    end

    -- 发送结束信息
    self:send_table(logic.INVALID_CHAIR, msg)

    --reset()

    -- 局数用完结束
end

-- 派发扑克
function M:dispatch_card_data(current_user, tail)
    -- 状态效验
    if current_user == logic.INVALID_CHAIR then
        return false
    end

    -- 丢弃扑克
    if self.out_card_user != logic.INVALID_CHAIR and self.out_card_data ~= 0 then
        self.discard_count[self.out_card_user] = self.discard_count[self.out_card_user] + 1
        self.discard_card[self.out_card_user][#self.discard_card[self.out_card_user] + 1] = self.out_card_data
    end

    -- 荒庄结束
    if self.left_card_count == 0 then
        self.chihu_card = 0
        self.provide_user = logic.INVALID_CHAIR
        self:over()
        return true
    end

    -- 设置变量
    self.out_card_data = 0
    self.current_user = current_user
    self.out_card_user = logic.INVALID_CHAIR
    self.enjoin_chihu[current_user] = false

    -- 发牌处理
    if self.send_status == true then
        -- 发送扑克
        self.send_card_count = self.send_card_count + 1
        self.send_card_data = self.repertory_card[self.left_card_count]
        self.left_card_count = self.left_card_count - 1

        -- 加牌
        local card_count = self.card_index[current_user][logic.card2index(self.send_card_data)]
        self.card_index[current_user][logic.card2index(self.send_card_data)] = card_count + 1

        -- 杠牌判断
        if self.enjoin_chipeng[current_user] == false and self.left_card_count > 1 then
            self.user_action[current_user] = self.user_action[current_user] | logic.analyse_gang_card(self.card_index[current_user])
        end

        --胡牌判断
        self.user_action[current_user] = self.user_action[current_user] | logic.analyse_chihu_card(self.card_index[self.banker_user], self.weave_item_array[current_user])
    end


    --//堆立信息
    --//assert( m_wHeapHand != INVALID_CHAIR && m_wHeapTail != INVALID_CHAIR )
    --if( !bTail )
    --{
    --//切换索引
    --uint8_t cbHeapCount=m_cbHeapCardInfo[m_wHeapHand][0]+m_cbHeapCardInfo[m_wHeapHand][1]
    --if (cbHeapCount==HEAP_FULL_COUNT)
    --m_wHeapHand=(m_wHeapHand+1)%CountArray(m_cbHeapCardInfo)
    --m_cbHeapCardInfo[m_wHeapHand][0]++
    --}
    --else
    --{
    --//切换索引
    --uint8_t cbHeapCount=m_cbHeapCardInfo[m_wHeapTail][0]+m_cbHeapCardInfo[m_wHeapTail][1]
    --if (cbHeapCount==HEAP_FULL_COUNT)
    --m_wHeapTail=(m_wHeapTail+3)%CountArray(m_cbHeapCardInfo)
    --m_cbHeapCardInfo[m_wHeapTail][1]++
    --}

    local msg = {
        cmd = "send_card",
        current_user = current_user,
        action_mask = self.user_action[current_user],
        card_data = self.send_status == true and self.send_card_data or 0x00
    }

    self:send_table(logic.INVALID_CHAIR, msg)

    --// TODO timer
end

-- 响应判断
function M:estimate_user_respond(center_user, center_card, is_out_card)
    -- 变量定义
    local arose_action = false

    -- 用户状态
    self.response = {false, false, false, false}
    self.user_action = {0, 0, 0, 0}
    self.perform_action = {0, 0, 0, 0}

    -- 动作判断
    for i = 1, self.player_count do
        -- 用户过滤
        if center_user ~= i then 
            -- 出牌类型
            if is_out_card == true then
                -- 吃碰判断
                if self.enjoin_chipeng[i] == false then
                    -- 碰牌判断
                    self.user_action[i]= self.user_action[i] | logic.estimate_peng_card(self.card_index[i], center_card)

                    -- 吃牌判断
                    local eat_user = (center_user - 1) % self.player_count + 1
                    if eat_user == i then
                        self.user_action[i] = self.user_action[i] | logic.estimate_eat_card(self.card_index[i], center_card)
                    end

                    -- 杠牌判断
                    if self.left_card_count > 1 then 
                        self.user_action[i] = self.user_action[i] | logic.estimate_gang_card(self.card_index[i], center_card)
                    end
                end
            end

            -- 胡牌判断
            if self.enjoin_chihu[i] == false then
                --胡牌判断
                self.user_action[i] = self.user_action[i] | logic.analyse_chihu_card(self.card_index[i], self.weave_item_array[i], center_card)

                -- 吃胡限制
                if (self.user_action[i] & logic.WIK_CHI_HU) ~= 0 then 
                    self.enjoin_chihu[i]=true
                end
            end

            -- 结果判断
            if self.user_action[i] ~= logic.WIK_NULL then 
                arose_action = true
            end
        end
    end

    -- 结果处理
    if arose_action == true then
        -- 设置变量
        self.provide_user = center_user
        self.provide_card = center_card 
        self.resume_user = self.current_user
        self.current_user = logic.INVALID_CHAIR

        -- 发送提示
        self:send_operate_notify()
        return true
    end

    return false
end

-- 用户托管
function M:trustee(chairid, trustee) 
    self.trustee[chairid] = trustee
    -- 构造数据
    local msg = {
        cmd = "trustee",
        trustee = trustee,
        chairid = chairid
    }
    -- 发送消息
    self:send_table(logic.INVALID_CHAIR, msg)
end

-- 用户进入
function M:enter(player)
    local chairid = logic.INVALID_CHAIR
    for i=1, logic.GAME_PLAYER do
        if next(self.player[i]) == nil then
            chairid = i
            player.chairid = i
            self.player[i] = player
        end
    end

    if chairid == logic.INVALID_CHAIR then 
        return chairid
    end

    local msg = {
        cmd = "enter",
        player = self.player
    }
    send_table(logic.INVALID_CHAIR, msg)

    return chairid
end

-- 用户准备
function M:ready(chairid) 
    self.ready[chairid] = true
    for i=1, logic.GAME_PLAYER do
        if not self.ready[i] then
            local msg = {
                cmd = "ready",
                ready_user = chairid
            }
            --发送消息
            self:send_table(logic.INVALID_CHAIR, msg)
            return
        end
    end

    self:start()
end

-- 用户离开
function M:leave(chairid)
    if self.ready[chairid] == true then
        return false
    end
    self.ready[chairid]=false
    local msg = {
        cmd = "leave",
        leave_user = chairid
    }
    self:send_table(logic.INVALID_CHAIR, msg)

    -- 再移除
    self.player[chairid] = {}

    -- 没人删除游戏
    if #self.player == 0 then 
        self = nil
    end

    return true
end

-- 用户被踢
function M:kick(chairid)
    if game_status then
        return false 
    end

    if chairid == self.room_owner then
        return false 
    end

    self.ready[chairid] = false

    self:send_table(logic.INVALID_CHAIR, {cmd = "kick", kick_user = chairid})

    -- 再移除
    self.player[chairid] = {}

    return true
end


-- 用户听牌
function M:listen(chairid)
    -- TODO if is_listen
    self.enjoin_chipeng[chairid] = true

    self:send_table(logic.INVALID_CHAIR, {cmd = "listen", listen_user = chairid})
end


-- 用户出牌
function M:out_card(chairid, card_data)
    -- 效验参数
    if chairid ~= self.current_user then
        return false
    end

    if not logic.is_valid_card(card_data) then
        return false
    end

    -- 删除扑克
    if not logic.remove_card(self.card_index[chairid], card_data) then
        return false
    end

    --StopAllTimer()

    --设置变量
    self.send_status = true
    self.user_action[chairid] = logic.WIK_NULL
    self.perform_action[chairid] = logic.WIK_NULL

    -- 出牌记录
    self.out_card_count = self.out_card_count + 1 
    self.out_card_user = chairid
    self.out_card_data = card_data

    local msg = {
        cmd = "out_card",
        out_card_user = chairid,
        out_card_data = card_data
    }

    --发送消息
    self.send_table(logic.INVALID_CHAIR, msg)

    self.provide_user = chairid
    self.providecard = card_data

    --用户切换
    self.current_user = (chairid - 1) % self.player_count + 1
    --while( !m_bPlayStatus[m_wCurrentUser] )
    --m_wCurrentUser=(m_wCurrentUser+m_wPlayerCount-1)%m_wPlayerCount

    -- 响应判断
    local arose_action = self:estimate_user_respond(chairid, card_data, true)
    -- 派发扑克
    if not arose_action then
        self:dispatch_card_data(self.current_user)
    end
end

-- 用户操作
function M:operate_card(chairid, operate_code, operate_card)
    -- 效验用户
    if (chairid ~= self.current_user) and (self.current_user ~= logic.INVALID_CHAIR) then 
        return false
    end

    -- 被动动作
    if self.current_user == logic.INVALID_CHAIR then
        -- 效验状态
        if self.response[chairid] == true then 
            return false
        end
        if (operate_code ~= logic.WIK_NULL) and ((self.user_action[chairid] & operate_code) == 0) then
            return false
        end

        local target_user = chairid
        local target_action = operate_code

        self.response[chairid] = true
        self.perform_action[chairid] = operate_code
        self.operate_card[chairid] = operate_card == 0 and self.provide_card or operate_card

        for i=0, logic.GAME_PLAYER do
            -- 获取动作
            local user_action = self.response[i] == false and self.user_action[i] or self.perform_action[i]
            -- 优先级别
            local user_action_rank = logic.get_user_action_rank(user_action)
            local target_action_rank = logic.get_user_action_rank(target_action)

            if user_action_rank > target_action_rank then
                target_user = i
                target_action = user_action
            end
        end

        if self.response[target_user] == false then
            return true
        end

        -- 吃胡等待
        if target_action == logic.WIK_CHI_HU then
            -- TODO
            --for i=(self.provide_user - 1) % GAME_PLAYER, i!=self.provide_user, i=(i - 1) % GAME_PLAYER do
            for i = 1, logic.GAME_PLAYER do
                -- 截胡 不用等待所有回应
                --if (self.response[i] == true) and ((self.user_action[i] & WIK_CHI_HU) ~= 0) and ((self.perform_action[i] & WIK_CHI_HU) ~= 0) then
                --break
                --end

                if (self.response[i] == false) and (self.user_action[i] & logic.WIK_CHI_HU) ~=0 then
                    return true
                end
            end
        end

        -- 放弃操作
        if target_action == logic.WIK_NULL then
            -- 用户状态
            self.response = {false, false, false, false}
            self.user_action = {0, 0, 0, 0}
            self.operate_card = {0, 0, 0, 0}
            self.perform_action = {0, 0, 0, 0}

            -- 发送扑克
            self:dispatch_card_data(self.resume_user)
            return true
        end

        -- 变量定义
        local target_card = self.operate_card[target_user]

        -- 出牌变量
        self.out_card_data = 0
        self.send_status = true
        self.out_card_user = logic.INVALID_CHAIR
        self.enjoin_chihu[target_user] = false

        -- 胡牌操作
        if target_action == logic.WIK_CHI_HU then
            -- 结束信息
            self.chihu_card = target_card.
            -- 吃牌权位

            -- 胡牌判断
            for i = 1, GAME_PLAYER do
                -- 过虑判断
                if (i ~= self.provide_user) and (self.perform_action[i] & logic.WIK_CHI_HU) ~= 0 then
                    -- 普通胡牌
                    if self.chihu_card ~= 0 then
                        -- 胡牌判断
                        self.chihu_mask[i] = logic.analyse_chihu_card(self.card_index[i], self.weave_item[i], self.chihu_card)
                        -- 插入扑克
                        if self.chihu_mask[i] ~= logic.WIK_NULL then 
                            local card_count = self.card_index[i][logic.card2index(self.chihu_card)]
                            self.card_index[i][logic.card2index(self.chihu_card)] = card_count + 1
                        end
                    end
                end
                -- 结束游戏
                over()
                return true
            end
        end

        -- 用户状态
        self.response = {false, false, false, false}
        self.user_action = {0, 0, 0, 0}
        self.operate_card = {0, 0, 0, 0}
        self.perform_action = {0, 0, 0, 0}

        -- 组合扑克
        local index = #self.weave_item_array[target_user]
        asser(index < 5)
        index = index + 1
        self.weave_item_array[target_user][index].public_card = true
        self.weave_item_array[target_user][index].center_card = target_card
        self.weave_item_array[target_user][index].weave_type = target_action
        self.weave_item_array[target_user][index].provide_user = self.provide_user == logic.INVALID_CHAIR and target_user or provide_user

        -- 删除扑克
        if target_action == logic.WIK_LEFT then
            local remove_card = {target_card + 1, target_card + 2}
            logic.remove_card(self.card_index[target_user], remove_card)

        elseif target_action == logic.WIK_RIGHT then
            local remove_card = {target_card - 2, target_card - 1}
            logic.remove_card(self.card_index[target_user], remove_card)

        elseif target_action == logic.WIK_CENTER then
            local remove_card = {target_card - 1, target_card + 1}
            logic.remove_card(self.card_index[target_user], remove_card)

        elseif target_action == logic.WIK_PENG then
            local remove_card = {target_card, target_card}
            logic.remove_card(self.card_index[target_user], remove_card)

        elseif target_action == logic.WIK_GANG then
            local remove_card = {target_card, target_card, target_card}
            logic.remove_card(self.card_index[target_user], remove_card)

        else 
            assert(false)
        end

        local msg = {
            cmd = "operate_card",
            operate_user = target_user,
            operate_card = target_card,
            operate_code = target_action,
            provide_user = self.provide_user == logic.INVALID_CHAIR and target_user or self.provide_user
        }
        self:send_table(logic.INVALID_CHAIR, msg)

        -- 设置用户
        self.current_user = target_user

        -- 杠牌处理
        if target_action == logic.WIK_GANG then
            self.gang_status = true
            self:dispatch_card_data(Target_User, false)
        end

        return true
    end



    -- 主动动作
    if self.current_user == chairid then
        -- 效验操作
        if operate_code == logic.WIK_NULL or ((self.user_action[chairid] & operate_code) == 0) then
            return false
        end

        -- 扑克效验
        if operate_code ~= logic.WIK_NULL and cbOperateCode ~= logic.WIK_CHI_HU and logic.is_valid_card(operate_card) == false then
            return false
        end

        -- 设置变量
        self.send_status = true
        self.enjoin_chihu[self.current_user] = false
        self.user_action[self.current_user] = logic.WIK_NULL
        self.perform_action[self.current_user] = logic.WIK_NULL

        local public = false

        -- 执行动作
        if operate_code == logic.WIK_GANG or operate_code == logic.WIK_FILL then
            -- 变量定义
            local weave_index = 0xFF
            local card_index = logic.card2index(operate_card)

            -- 杠牌处理
            if self.card_index[chairid][card_index] == 1 then
                -- 寻找组合
                for i = 1, #self.weave_item_array[chairid] do
                    local weave_type = self.weave_item_array[chairid][i].weave_type
                    local center_card = self.weave_item_array[chairid][i].center_card
                    if center_card == operate_card and weave_type == logic.WIK_PENG then
                        public = true
                        weave_index = i
                        break
                    end
                end

                -- 效验动作
                if weave_index == 0xFF then
                    return false
                end

                -- 组合扑克
                self.weave_item_array[chairid][weave_index].public_card = true
                self.weave_item_array[chairid][weave_index].provide_user = chairid
                self.weave_item_array[chairid][weave_index].weave_type = operate_code
                self.weave_item_array[chairid][weave_index].center_card = operate_card
            else
                -- 扑克效验
                if self.card_index[chairid][card_index] != 4 then 
                    return false
                end

                -- 设置变量
                public = false
                weave_index = #self.weave_item_array[chairid]
                weave_index = weave_index + 1
                self.weave_item_array[chairid][weave_index].public_card = true
                self.weave_item_array[chairid][weave_index].provide_user = chairid
                self.weave_item_array[chairid][weave_index].weave_type = operate_code
                self.weave_item_array[chairid][weave_index].center_card = operate_card
            end

            -- 删除扑克
            self.card_index[chairid][card_index] = 0

            -- 设置状态
            if operate_code == logic.WIK_GANG then
                self.gang_status = true
            end

            local msg = {
                cmd = "operate_card",
                operate_user = chairid,
                provide_user = chairid,
                operate_card = operate_card,
                operate_code = operate_code
            }
            self:send_table(logic.INVALID_CHAIR, msg)

            --效验动作
            local arose_action = false
            if public == true then
                arose_action = self:estimate_user_respond(chairid, operate_card, false)
            end

            -- 发送扑克
            if arose_action == false then
                self:dispatch_card_data(chairid)
            end

            return true
        elseif operate_code == logic.WIK_CHI_HU then
            if self.out_card_count == 0 then
                self.provide_user = self.current_user
                self.provide_card = self.send_card_data
            end

            -- 胡牌判断
            self.chihu_mask[i] = logic.analyse_chihu_card(self.card_index[i], self.weave_item[i])

            -- 结束信息
            self.chihu_card = self.provide_card

            -- 结束游戏
            self:over()

            return true
        else
            assert(false)
        end
    end

    return false
end

return M

