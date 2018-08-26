#include <sourcemod>

public Plugin myinfo =
{
	name = "Fortnite Storm Circle",
	author = "Maciej Wrzesiński",
	description = "Storm Circle feature from Fortnite",
	version = "0.1",
	url = "https://github.com/maciej-wrzesinski/"
};

float g_fMapRadius;

ConVar cvStartTime;
float g_fCvarStartTime;
ConVar cvShrinkDuration;
float g_fCvarShrinkDuration;
ConVar cvStandDuration;
float g_fCvarStandDuration;
ConVar cvDamage;
float g_fCvarDamage;

Handle g_hHUD;

public void OnPluginStart()
{
	cvStartTime = CreateConVar("fsc_start", "60.0", "After how many seconds does the Storm Circle start?", _, true, 0.1, true, 999.0);
	cvShrinkDuration = CreateConVar("fsc_shrink_duration", "60.0", "How many seconds of shrinking does it take for Storm Circle until it stands?", _, true, 0.1, true, 999.0);
	cvStandDuration = CreateConVar("fsc_stand_duration", "60.0", "After how many seconds does the Storm Circle shrinks again?", _, true, 0.1, true, 999.0);
	cvDamage = CreateConVar("fsc_damage", "1.0", "How much damage should Storm Circle deal per 0.1 second? (0.0 = instant death)", _, true, 0.0, true, 999.0);
	
	g_hHUD = CreateHudSynchronizer();
	
}

public void OnConfigsExecuted()
{
	g_fCvarStartTime = GetConVarFloat(cvStartTime);
	g_fCvarShrinkDuration = GetConVarFloat(cvShrinkDuration);
	g_fCvarStandDuration = GetConVarFloat(cvStandDuration);
	g_fCvarDamage = GetConVarFloat(cvDamage);
}

public void OnMapStart()
{
	
	//Get map radius
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
	g_fMapRadius = fWorldMaxVec[0] - fWorldMinVec[0] > fWorldMaxVec[1] - fWorldMinVec[1] ? fWorldMaxVec[0] - fWorldMinVec[0] : fWorldMaxVec[1] - fWorldMinVec[1];
	
	//Begin the Storm Circle
	CreateTimer(g_fCvarStartTime, StormBegin);
	CreateTimer(g_fCvarStartTime, StormDealDamage);
}

//Storm stuff
public void StormBegin()
{
	//timer 0.1 to shrink the storm
}

public void StormShrink()
{
	//timer 'cvar time' to shrink the storm again
}

public void StormDealDamage()
{
	//deal damage to those outside the circle
}
