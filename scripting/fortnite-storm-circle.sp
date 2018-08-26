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
	version = "0.2",
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
float g_fCvarStartTime;
float g_fCvarShrinkDuration;
float g_fCvarShrinkAmount;
float g_fCvarStandDuration;
float g_fCvarDamage;
float g_fCvarTickRate;

char g_cSpriteLaser[] = "materials/sprites/laserbeam.vmt";
char g_iSpriteLaser;

public void OnPluginStart()
{
	cvStartTime = CreateConVar("fsc_start", "0.1", "After how many seconds does the Storm Circle start? (0.0 = never)", _, true, 0.1, true, 999.0);
	cvShrinkDuration = CreateConVar("fsc_shrink_duration", "5.0", "How many seconds of shrinking does it take for Storm Circle until it stands?", _, true, 0.1, true, 999.0);
	cvShrinkAmount = CreateConVar("fsc_shrink_amount", "1.0", "How many units the Storm Circle shrinks per one tick?", _, true, 0.5, true, 999.0);
	cvStandDuration = CreateConVar("fsc_stand_duration", "5.0", "After how many seconds does the Storm Circle shrinks again?", _, true, 0.1, true, 999.0);
	cvDamage = CreateConVar("fsc_damage", "1.0", "How much damage should Storm Circle deal per one tick? (0.0 = instant death)", _, true, 0.0, true, 999.0);
	cvTickRate = CreateConVar("fsc_tickrate", "0.1", "How often does the Storm Circle updates its visuals and deals damage? (small values recomended)", _, true, 0.1, true, 10.0);
}

public void OnConfigsExecuted()
{
	g_fCvarStartTime = GetConVarFloat(cvStartTime);
	g_fCvarShrinkDuration = GetConVarFloat(cvShrinkDuration);
	g_fCvarShrinkAmount = GetConVarFloat(cvShrinkAmount);
	g_fCvarStandDuration = GetConVarFloat(cvStandDuration);
	g_fCvarDamage = GetConVarFloat(cvDamage);
	g_fCvarTickRate = GetConVarFloat(cvTickRate);
}

public void OnMapStart()
{
	//Download sprite
	g_iSpriteLaser = PrecacheModel(g_cSpriteLaser);
	
	//Get map radius and origin
	float fWorldMinVec[3], fWorldMaxVec[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", fWorldMinVec);
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", fWorldMaxVec);
	
	float fNormalVec[3] = {1.0, 1.0, 1.0};
	while(TR_PointOutsideWorld(fWorldMinVec))
		AddVectors(fWorldMinVec, fNormalVec, fWorldMinVec);
	
	ScaleVector(fNormalVec, -1.0);
	while(TR_PointOutsideWorld(fWorldMaxVec))
		AddVectors(fWorldMaxVec, fNormalVec, fWorldMaxVec);
	
	//Getting the bigger number out of X and Y and saving it as map radius (maximum Storm Circle size)
	g_fStormMaxRadius = fWorldMaxVec[0] - fWorldMinVec[0] > fWorldMaxVec[1] - fWorldMinVec[1] ? fWorldMaxVec[0] - fWorldMinVec[0] : fWorldMaxVec[1] - fWorldMinVec[1];
	g_fStormCurrentRadius = g_fStormMaxRadius;
	
	//Center bottom of the map
	fWorldMaxVec[2] = 0.0;
	AddVectors(fWorldMinVec, fWorldMaxVec, g_fStormOrigin);
	
	//Highest and lowest points of the Storm
	g_fStormMaxZ = fWorldMaxVec[2];
	g_fStormMinZ = fWorldMinVec[2];
	
	//Begin the Storm Circle
	if (g_fCvarStartTime != 0.0)
	{
		CreateTimer(g_fCvarStartTime, StormBegin);
		CreateTimer(g_fCvarStartTime, StormDealDamageAndDrawAndShrink);
	}
}

public Action StormBegin(Handle hTimer)
{
	PrintToChatAll("Storm Circle begins!");
	CreateTimer(0.1, StormShrink);
}

public Action StormShrink(Handle hTimer)
{
	PrintToChatAll("Storm Circle shrinks! Next shrink in %f seconds!", g_fCvarShrinkDuration + g_fCvarStandDuration);
	g_bStormIsShrinking = true;
	CreateTimer(g_fCvarShrinkDuration, StormStand);
}

public Action StormStand(Handle hTimer)
{
	PrintToChatAll("Storm Circle stands! Next shrink in %f seconds!", g_fCvarShrinkDuration);
	g_bStormIsShrinking = false;
	CreateTimer(g_fCvarStandDuration, StormShrink);
}

public Action StormDealDamageAndDrawAndShrink(Handle hTimer)
{
	//Deal damage to those outside the circle
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsClientValid(i) && !IsClientSourceTV(i) && IsPlayerAlive(i))
		{
			float PlayerOrigin[3];
			GetClientAbsOrigin(i, PlayerOrigin);
			
			if (GetVectorDistance(PlayerOrigin, g_fStormOrigin, true) > g_fStormMaxRadius)
			{
				//Take damage here (print for debug)
				if (g_fCvarDamage == 0.0)
					PrintToChat(i, "Excuse me but the Storm Circle kills you %f > %f", GetVectorDistance(PlayerOrigin, g_fStormOrigin, true), g_fStormMaxRadius);
				else
					PrintToChat(i, "Excuse me but the Storm Circle deals damage to you %f > %f", GetVectorDistance(PlayerOrigin, g_fStormOrigin, true), g_fStormMaxRadius);
			}
		}
	}
	
	//Shrink if needed
	if (g_bStormIsShrinking == true)
	{
		g_fStormCurrentRadius -= g_fCvarShrinkAmount;
	}
	
	//Draw the Storm
	StormDrawBeamPoints();
	
	//Repeat
	CreateTimer(g_fCvarTickRate, StormDealDamageAndDrawAndShrink);
}

stock void StormDrawBeamPoints()
{
	float fStormRingsVertDist = 20.0;
	
	float fBeamWidth = g_fStormCurrentRadius;
	int iStartFrame = 0;
	int iFrameRate = 10;
	float fLife = 10.0;
	int iColorsRGBA[4] = {255, 255, 255, 255};
	
	float fTemporaryOrigin[3];
	fTemporaryOrigin[0] = g_fStormOrigin[0];
	fTemporaryOrigin[1] = g_fStormOrigin[1];
	fTemporaryOrigin[2] = g_fStormOrigin[2];
	
	for (float f = g_fStormMinZ; f < g_fStormMaxZ; f += fStormRingsVertDist)
	{
		TE_SetupBeamRingPoint(fTemporaryOrigin, fBeamWidth, fBeamWidth+0.1, g_iSpriteLaser, g_iSpriteLaser, iStartFrame, iFrameRate, fLife, 2.0, 0.0, iColorsRGBA, 10, 0);
		TE_SendToAllInRange(fTemporaryOrigin, RangeType_Visibility, 0.0);
		
		fTemporaryOrigin[2] += f;
	}
}

stock bool IsClientValid(int client)
{
	return (client > 0 && client <= MAX_PLAYERS && IsClientInGame(client));
}

