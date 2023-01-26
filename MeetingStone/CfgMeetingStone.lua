U1RegisterAddon("MeetingStone", {
    title = "集合石组团",
    tags = { TAG_GOOD, TAG_RAID, TAG_BIG },
    icon = [[Interface\AddOns\MeetingStone\Media\Logo]],
    minimap = "LibDBIcon10_MeetingStone",
    nopic = 1,
	defaultEnable = 1,
    load="NORMAL" , --有人反馈说有问题，先这么搞了
    desc = "【集合石组团】发布地址：https://gitee.com/xmmmmm/meeting-stone_-happy BUG反馈：丹彤-贫瘠之地",
});

U1RegisterAddon("MeetingStoneEX", {
    parent = "MeetingStone",
    title = "集合石扩展",
    author = "玩偶风暴指挥官@NGA",
})
