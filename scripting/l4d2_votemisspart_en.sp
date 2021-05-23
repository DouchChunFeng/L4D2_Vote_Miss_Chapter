#include <sourcemod>
#include <sdktools>
#include <builtinvotes>

#define PLUGIN_VERSION "1.0"
new Handle:g_Vote = INVALID_HANDLE;
bool isFinal = false;
bool coldT = false;

public Plugin:myinfo =
{
	name = "[L4D2]Vote to Miss NowChapter",
	author = "Douch&春风",
	description = "Miss Current Chapter - 投票跳过当前关卡(章节)",
	version = PLUGIN_VERSION,
	url = "https://www.l4d.run"
}
public OnPluginStart()
{
	RegConsoleCmd("sm_vmap", MenuFunc_NextMap, "Are you Sure Start a Vote To Miss Chapter?");
	RegConsoleCmd("sm_vm", MenuFunc_NextMap, "Are you Sure Start a Vote To Miss Chapter?");
	HookEvent("round_start", Event_RoundStart);
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("finale_win",Event_FinaleWin);
	HookEvent("round_end",Event_RoundEnd);
}
public void Event_RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	coldT = true;
	CreateTimer(120.0, Timer_UnlockVote);
	char nowMap[100];
	GetCurrentMap(nowMap, sizeof(nowMap));

	if(StrEqual(nowMap,"c1m4_atrium" ,false) ||
		StrEqual(nowMap,"c2m5_concert" ,false) ||
		StrEqual(nowMap,"c3m4_plantation" ,false) ||
		StrEqual(nowMap,"c4m5_milltown_escape" ,false) ||
		StrEqual(nowMap,"c5m5_bridge" ,false) ||
		StrEqual(nowMap,"c6m3_port" ,false) ||
		StrEqual(nowMap,"c7m3_port" ,false) ||
		StrEqual(nowMap,"c8m5_rooftop" ,false) ||
		StrEqual(nowMap,"c9m2_lots" ,false) ||
		StrEqual(nowMap,"c10m5_houseboat" ,false) ||
		StrEqual(nowMap,"c11m5_runway" ,false) ||
		StrEqual(nowMap,"c12m5_cornfield" ,false) ||
		StrEqual(nowMap,"c13m4_cutthroatcreek" ,false) ||
		StrEqual(nowMap,"c14m2_lighthouse" ,false)) {

		isFinal = true;
		return;
	}
	isFinal = false;
}
public void Event_FinaleStart(Handle event, char[] name, bool dontBroadcast)
{
	isFinal = true;
}
public void Event_FinaleWin(Handle event, char[] name, bool dontBroadcast)
{
	isFinal = false;
}
public void Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	isFinal = false;
}
public Action Timer_UnlockVote(Handle:timer)
{
	coldT = false;
}
public Action:MenuFunc_NextMap(client, args)
{
	if(GetClientTeam(client)==1)
	{
		PrintToChat(client,"[SM] You (%N) in the Spec team, can not start a vote!",client);
		return;
	}
	if(InGamePlayers() <= 1)
	{
		PrintToChat(client,"[SM] Only you in Server, so you can not start a vote!");
		return;
	}
	if(isFinal == true)
	{
		PrintToChat(client,"[SM] Final Chapter Now. Can not start a vote!");
		return;
	}
	if(coldT == true)
	{
		PrintToChat(client,"[SM] Round start just now. You can not start a vote now.");
		return;
	}
	new Handle:menu = CreateMenu(MenuHandler_NextMap);	

	decl String:line[1024];
	decl String:nextmap[1024];
	
	GetCurrentMap(nextmap,sizeof(nextmap));
	Format(line, sizeof(line), "Start a Vote to MISS Chapter?\n(Teleport to Saferoom)\nCurrent Chapter:[%s]", nextmap);

	SetMenuTitle(menu, line);

	AddMenuItem(menu, "item0", "Yes");
	AddMenuItem(menu, "item1", "No");

	SetMenuExitBackButton(menu, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_NextMap(Handle:menu, MenuAction:action, client, item)
{
	if(action == MenuAction_Select)
	{
		switch(item)
		{
			case 0:
			{
				CreateTimer(0.3,Timer_StartVote,client);
			}
			case 1:
			{

			}
		}
	}
	else if(action == MenuAction_End)	
	{
		CloseHandle(menu);
	}
}

public Action Timer_StartVote(Handle timer,client)
{
	if (StartVote(client))
	{
		FakeClientCommand(client, "Vote Yes");
	}
}

bool:StartVote(client)
{
	if (IsNewBuiltinVoteAllowed())
	{
		g_Vote = CreateBuiltinVote(HandleVote, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		if (client > 0)
		{
			SetBuiltinVoteInitiator(g_Vote, client);
		}
		SetBuiltinVoteArgument(g_Vote, "Miss current chapter?\n(TP to Saferoom)"); //出现投票时标题
		DisplayBuiltinVoteToAll(g_Vote, 20); //20秒等待时间
		return true;
	}
	else
	{
		ReplyToCommand(client, "[SM:Vote]You can not start a vote now!");
		PrintToChat(client, "[SM:Vote]You can not start a vote now!");
		return false;
	}
}

public HandleVote(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_Vote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
		
		case BuiltinVoteAction_VoteEnd:
		{
			if (param1 == BUILTINVOTES_VOTE_YES) //赢了之后做的事
			{
				DisplayBuiltinVotePass(vote, "Success:\nTeleport All Survivors To Saferoom."); //投票成功输出

				CheatCommand(param1,"warp_all_survivors_to_checkpoint","");
				CheatCommand(param1,"warp_all_survivors_to_checkpoint","");
				CloseLockSafeDoor();
				
			}
			else if (param1 == BUILTINVOTES_VOTE_NO)
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			}
			else
			{
				// 这个不应该会执行，作为判断(诊断)
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
				LogMessage("Vote failure. winner = %d", param1);
			}
		}
	}
}



//找门与关门锁门
stock void CloseLockSafeDoor()
{
	int doorlocal;
	while((doorlocal = FindEntityByClassname(doorlocal,"prop_door_rotating_checkpoint")) != -1)
	{
		AcceptEntityInput(doorlocal ,"Close");
		AcceptEntityInput(doorlocal ,"Lock");
	}
}
//结束:找门与关门锁门


InGamePlayers()
{
	new counts = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) !=1)
		{
			counts++;
		}
	}
	return counts;
}

void CheatCommand(Client, const String:command[], const String:arguments[])
{
	if (!Client) return;
	new admindata = GetUserFlagBits(Client);
	SetUserFlagBits(Client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(Client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(Client, admindata);
}