#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon				1
#pragma newdecls				required

#define MAX_PLAYERS				64

public Plugin myinfo =
{
	name = "Fortnite Storm Circle",
	author = "Maciej Wrzesiński",
	description = "Storm Circle feature from Fortnite",
	version = "0.3",
	url = "https://github.com/maciej-wrzesinski/"
};

float g_fStormMaxRadius;
float g_fStormCurrentRadius;
float g_fStormOrigin[3];
float g_fStormMaxZ;
float g_fStormMinZ;
bool g_bStormIsShrinking = false;

ConVar cvStartTime;
ConVar cvShrinkDuration;
ConVar cvShrinkAmount;
ConVar cvStandDuration;
ConVar cvDamage;
ConVar cvTickRate;
ConVar cvColor;
float g_fCvarStartTime;
float g_fCvarShrinkDuration;
float g_fCvarShrinkAmount;
float g_fCvarStandDuration;
float g_fCvarDamage;
float g_fCvarTickRate;
int g_iCvarColor[4];

char g_cSpriteLaser[] = "materials/sprites/laserbeam.vmt";
char g_iSpriteLaser;

Handle g_hBeginTimer = INVALID_HANDLE;
Handle g_hFunctionTimer = INVALID_HANDLE;
Handle g_hTickTimer = INVALID_HANDLE;

public void OnPluginStart()
{
	cvStartTime = CreateConVar("fsc_start", "0.1", "After how many seconds does the Storm Circle start? (0.0 = never)", _, true, 0.1, true, 999.0);
	cvShrinkDuration = CreateConVar("fsc_shrink_duration", "10.0", "How many seconds of shrinking does it take for Storm Circle until it stands?", _, true, 0.1, true, 999.0);
	cvShrinkAmount = CreateConVar("fsc_shrink_amount", "20.0", "How many units the Storm Circle shrinks per one tick?", _, true, 0.5, true, 999.0);
	cvStandDuration = CreateConVar("fsc_stand_duration", "2.0", "After how many seconds does the Storm Circle shrinks again?", _, true, 0.1, true, 999.0);
	cvDamage = CreateConVar("fsc_damage", "1.0", "How much damage should Storm Circle deal per one tick? (0.0 = instant death)", _, true, 0.0, true, 999.0);
	cvTickRate = CreateConVar("fsc_tickrate", "0.1", "How often does the Storm Circle updates its visuals and deals damage? (small values recomended)", _, true, 0.1, true, 10.0);
	cvColor = CreateConVar("fsc_color", "50 50 255 200", "What color is the Storm Circle?", _);
	
	RegAdminCmd("sm_forcesc", CMD_StormForce, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	g_fCvarStartTime = GetConVarFloat(cvStartTime);
	g_fCvarShrinkDuration = GetConVarFloat(cvShrinkDuration);
	g_fCvarShrinkAmount = GetConVarFloat(cvShrinkAmount);
	g_fCvarStandDuration = GetConVarFloat(cvStandDuration);
	g_fCvarDamage = GetConVarFloat(cvDamage);
	g_fCvarTickRate = GetConVarFloat(cvTickRate);
	
	char tempstring[17];
	char tempstring2[5][5];
	GetConVarString(cvColor, tempstring, 16);
	ExplodeString(tempstring, " ", tempstring2, 4, 4);
	g_iCvarColor[0] = StringToInt(tempstring2[0]);
	g_iCvarColor[1] = StringToInt(tempstring2[1]);
	g_iCvarColor[2] = StringToInt(tempstring2[2]);
	g_iCvarColor[3] = StringToInt(tempstring2[3]);
}

public void OnMapStart()
{
	g_iSpriteLaser = PrecacheModel(g_cSpriteLaser);
}

public Action CMD_StormForce(int client, int args)
{
	if (IsValidHandle(g_hBeginTimer)) KillTimer(g_hBeginTimer);
	if (IsValidHandle(g_hFunctionTimer)) KillTimer(g_hFunctionTimer);
	if (IsValidHandle(g_hTickTimer)) KillTimer(g_hTickTimer);
	
	StormPrepare();
}

stock void StormPrepare()
{
	float fWorldMinVec[3], fWorldMaxVec[3], fOldWorldMinVec[3], fOldWorldMaxVec[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", fWorldMinVec);
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", fWorldMaxVec);
	
	//This shortens the range
	float fNormalVec[3] = {-1.0, -1.0, -1.0};
	AddVectors(fWorldMinVec, fNormalVec, fOldWorldMinVec);
	AddVectors(fWorldMaxVec, fNormalVec, fOldWorldMaxVec);
	ScaleVector(fNormalVec, -1.0);
	while(TR_PointOutsideWorld(fWorldMinVec))
		AddVectors(fWorldMinVec, fNormalVec, fWorldMinVec);
	ScaleVector(fNormalVec, -1.0);
	while(TR_PointOutsideWorld(fWorldMaxVec))
		AddVectors(fWorldMaxVec, fNormalVec, fWorldMaxVec);
	//...but not the height?
	fWorldMinVec[2] = fOldWorldMinVec[2];
	fWorldMaxVec[2] = fOldWorldMaxVec[2];
	
	//Getting the bigger number out of X and Y and saving it as map radius (maximum Storm Circle size)
	g_fStormMaxRadius = fWorldMaxVec[0] - fWorldMinVec[0] > fWorldMaxVec[1] - fWorldMinVec[1] ? fWorldMaxVec[0] - fWorldMinVec[0] : fWorldMaxVec[1] - fWorldMinVec[1];
	g_fStormMaxRadius = g_fStormMaxRadius > 4000.0 ? 4000.0 : g_fStormMaxRadius; //Out-of-range value
	g_fStormCurrentRadius = g_fStormMaxRadius;
	
	//Highest and lowest points of the Storm
	g_fStormMaxZ = fWorldMaxVec[2];
	g_fStormMinZ = fWorldMinVec[2];
	
	//Center bottom of the map
	fWorldMaxVec[2] = 0.0;
	AddVectors(fWorldMinVec, fWorldMaxVec, g_fStormOrigin);
	
	//Begin the Storm Circle
	if (g_fCvarStartTime != 0.0)
	{
		g_hBeginTimer = CreateTimer(g_fCvarStartTime, StormBegin);
		g_hFunctionTimer = CreateTimer(g_fCvarStartTime, StormFunction);
	}
}

public Action StormBegin(Handle hTimer)
{
	PrintToChatAll("Storm Circle begins!");
	CreateTimer(0.1, StormShrink);
}

public Action StormShrink(Handle hTimer)
{
	if (g_fStormCurrentRadius == 0.0)
	{
		PrintToChatAll("Storm Circle stops!");
		return;
	}
	
	PrintToChatAll("Storm Circle shrinks! Next shrink in %f seconds!", g_fCvarShrinkDuration + g_fCvarStandDuration);
	g_bStormIsShrinking = true;
	g_hBeginTimer = CreateTimer(g_fCvarShrinkDuration, StormStand);
}

public Action StormStand(Handle hTimer)
{
	PrintToChatAll("Storm Circle stands! Next shrink in %f seconds!", g_fCvarShrinkDuration);
	g_bStormIsShrinking = false;
	g_hBeginTimer = CreateTimer(g_fCvarStandDuration, StormShrink);
}

public Action StormFunction(Handle hTimer)
{
	//Deal damage to those outside the circle
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsClientValid(i) && !IsClientSourceTV(i) && IsPlayerAlive(i))
		{
			float PlayerOrigin[3];
			GetClientAbsOrigin(i, PlayerOrigin);
			PlayerOrigin[2] = 0.0; //because the storms origin Z is also 0.0
			
			if (GetVectorDistance(PlayerOrigin, g_fStormOrigin, false) > (g_fStormCurrentRadius/2)+70.0)//+70 for better particle matching
			{
				if (g_fCvarDamage == 0.0)
					SDKHooks_TakeDamage(i, 0, 0, 9999.0);
					//PrintToChat(i, "Excuse me but the Storm Circle kills you %f > %f", GetVectorDistance(PlayerOrigin, g_fStormOrigin, false), g_fStormCurrentRadius/2);
				else
					SDKHooks_TakeDamage(i, 0, 0, g_fCvarDamage);
					//PrintToChat(i, "Excuse me but the Storm Circle deals damage to you %f > %f", GetVectorDistance(PlayerOrigin, g_fStormOrigin, false), g_fStormCurrentRadius/2);
			}
		}
	}
	
	//Shrink if needed
	if (g_bStormIsShrinking == true)
	{
		g_fStormCurrentRadius = g_fStormCurrentRadius - g_fCvarShrinkAmount > 0.0 ? g_fStormCurrentRadius - g_fCvarShrinkAmount : 0.0;
	}
	
	//Draw the Storm
	StormDrawBeamPoints();
	
	//Repeat
	g_hTickTimer = CreateTimer(g_fCvarTickRate, StormFunction);
}

stock void StormDrawBeamPoints()
{
	float fNumOfParticles = 5.0;
	
	float fBeamWidth = g_fStormCurrentRadius;
	int iStartFrame = 0;
	int iFrameRate = 0;
	float fLife = 0.2;
	float fFullHeight = g_fStormMaxZ-g_fStormMinZ;
	float fLineWidth = fFullHeight/fNumOfParticles > 200.0 ? 200.0 : fFullHeight/fNumOfParticles; //Out-of-range value
	
	float fTemporaryOrigin[3];
	fTemporaryOrigin[0] = g_fStormOrigin[0];
	fTemporaryOrigin[1] = g_fStormOrigin[1];
	fTemporaryOrigin[2] = g_fStormOrigin[2];
	
	for (int i = 0; i < fNumOfParticles; i++)
	{
		TE_SetupBeamRingPoint(fTemporaryOrigin, fBeamWidth, fBeamWidth+0.3, g_iSpriteLaser, g_iSpriteLaser, iStartFrame, iFrameRate, fLife, fLineWidth, 0.0, g_iCvarColor, 10, 0);
		TE_SendToAll(0.1);
		
		fTemporaryOrigin[2] += fLineWidth;
	}
}

stock bool IsClientValid(int client)
{
	return (client > 0 && client <= MAX_PLAYERS && IsClientInGame(client));
}
