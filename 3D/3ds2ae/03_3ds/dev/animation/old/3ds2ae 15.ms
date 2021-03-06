---------------------------------------------------------------------------------------------------
-- global declarations
---------------------------------------------------------------------------------------------------
global ro1

fn max2AESel =
(
	ro1.sel=(getcurrentselection())[1]
	ro1.handleSelection()
)

rollout ro1 "Options" width:232 height:336
(
	---------------------------------------------------------------------------------------------------
	-- declarations
	---------------------------------------------------------------------------------------------------

	local sel, obj, objClass
	local compHeight, compWidth
	local data
	local mxYUP=matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,0]--XZY
	local mxZUP=matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]--XYZ
	local mxYUP=matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,0]

	---------------------------------------------------------------------------------------------------
	-- Interface
	---------------------------------------------------------------------------------------------------

	GroupBox grp3ds "3dsmax" pos:[8,8] width:216 height:40
	checkbutton btnLock "L" pos:[200,24] width:16 height:16 toolTip:"Press to lock"
	label lblObj "Pick an object, camera or light..." pos:[16,24] width:184 height:16
	GroupBox grpAE "After Effects" pos:[8,56] width:216 height:80
	dropdownList ddCompPreset "" pos:[16,80] width:140 height:21 items:#("Custom Output Size...", "Current Settings...", "PAL (720 x 576)", "PAL (1024 x 756)")
	dropdownList ddAEVersion "" pos:[156,80] width:60 height:21 items:#("6.5", "6.0", "5.5", "5.0")
	spinner spnCompWidth "Width: " pos:[32,108] width:80 height:16 range:[0,9999,400] type:#integer scale:1
	spinner spnCompHeight "Height: " pos:[136,108] width:80 height:16 range:[0,9999,400] type:#integer scale:1
	GroupBox grpExport "Properties" pos:[8,144] width:216 height:72
	checkbox chkPos "Position" pos:[16,160] width:96 height:16 checked:true
	checkbox chkRot "Rotation" pos:[16,176] width:96 height:16 checked:true
	checkbox chkScale "Scale" pos:[16,192] width:96 height:16
	checkbox chkCam "Camera properties" pos:[112,160] width:104 height:16 enabled:false checked:true
	checkbox chkLight "Light properties" pos:[112,176] width:104 height:16 enabled:false checked:true
	checkbox chkTarg "Target" pos:[112,192] width:110 height:16 enabled:false checked:true
	GroupBox grpAnimRange "Animation Range" pos:[8,224] width:216 height:72

--	dropdownList ddAnimRange "" pos:[16,240] width:200 height:21 items:#("Single frame", "Current range", "Custom...")
--	spinner spnAnimFrom "From: " pos:[32,268] width:80 height:16 range:[0,9999,0] type:#integer scale:1
--	spinner spnAnimTo "To: " pos:[144,268] width:70 height:16 range:[0,9999,100] type:#integer scale:1


	radiobuttons rdoAnimRange "" pos:[16,240] width:87 height:48 labels:#("Single Frame", "Current range", "Custom") columns:1
	spinner spnAnimFrom "From: " pos:[155,249] width:61 height:16 range:[0,9999,0] type:#integer scale:1
	spinner spnAnimTo "To: " pos:[160,269] width:56 height:16 range:[0,9999,100] type:#integer scale:1



	button btnExport "Output data to listener..." pos:[8,304] width:216 height:24

	---------------------------------------------------------------------------------------------------
	-- Functions
	---------------------------------------------------------------------------------------------------

	fn trimFloat val n=
	(
		local p=10^n
		return floor(val*p)/p
	)

	fn getVal val=
	(
		val=trimFloat val 1
		if abs val < 0.1 then val=0
		return val
	)

	fn handleSelection=
	(
		if NOT btnLock.state then
		(
			obj=sel
			if sel!=undefined then
			(
				lblObj.text=obj.name
				objClass=superclassof obj
			)
			else(
				lblObj.text="Pick an object, camera or light..."
			)
			chkLight.enabled= 	objClass==light
			chkCam.enabled=	objClass==camera
			btnExport.enabled=(obj!=undefined)
		)
	)


	fn setAnimRange=
	(
		local animRange=#()
		animRange=case rdoAnimRange.state of
		(
			1:	#(sliderTime,sliderTime)
			2:	#(animationrange.start,animationrange.end)
			3:	#(spnAnimFrom.value,spnAnimTo.value)
		)
		spnAnimFrom.value=animRange[1]
		spnAnimTo.value=animRange[2]
	)

	fn setCompSize=
	(
		local xy=#()
		xy=case ddCompPreset.selection of
		(
			1:	#(spnCompWidth.value,spnCompHeight.value)
			2:	#(renderwidth,renderheight)
			3:	#(720,576)
			4:	#(1024,576)
		)
		spnCompWidth.value=xy[1]
		spnCompHeight.value=xy[2]
	)


	---------------------------------------------------------------------------------------------------
	-- Handlers
	---------------------------------------------------------------------------------------------------

-- 3dsmax

	on ro1 open do 
	(
		callbacks.addScript #selectionSetChanged "max2AESel()" id:#max2aeCallback
		ddCompPreset.selection=2
		setCompSize()
		rdoAnimRange.state=1
		--chkPos.checked=false
		setAnimRange()
		max2AESel()
		--if setClipboardText!=undefined then btnExport.text="Copy data to clipboard..." 

	)

	on ro1 close do callbacks.removeScripts id:#max2aeCallback

	on btnLock changed state do handleSelection()



-- After Effects

	on ddCompPreset selected item do setCompSize()

	on spnCompWidth changed val do ddCompPreset.selection=1
	on spnCompHeight changed val do ddCompPreset.selection=1


-- Animation range

	on rdoAnimRange changed state do setAnimRange()

	on spnAnimFrom changed val do
	(
		rdoAnimRange.state=3
		if spnAnimFrom.value >= spnAnimTo.value then spnAnimTo.value = spnAnimFrom.value
	)

	on spnAnimTo changed val do
	(
		rdoAnimRange.state=3
		if spnAnimTo.value <= spnAnimFrom.value then spnAnimFrom.value = spnAnimTo.value
	)

-- Export

	on btnExport pressed do
	(

	-- variables
		local posData=stringstream ""
		local rotData=stringstream ""
		local scaleData=stringstream ""

		local targData=stringstream ""
		local FOVData=stringstream ""
		local lightData=stringstream ""

	-- initial data		
		-- PRS
			if chkPos.checked then 
				format "\nPosition\n	Frame	X pixels	Y pixels	Z pixels\n" to:posData
				
			if (chkRot.checked AND obj.target==undefined) then
				format "\nOrientation\n	Frame	degrees\n" to:rotData
				
			if chkScale.checked then 
				format  "\nScale\n	Frame	X percent	Y percent	Z percent\n" to:scaleData
			
		-- targetted objects
			if ((chkCam.checked OR chkLight.checked) AND obj.target!=undefined) then 
				format "\nPoint of Interest\n	Frame	X pixels	Y pixels	Z pixels\n" to:targData
	
		-- cameras
			if (chkCam.checked AND (superclassof obj)==camera) then 
				format "\nZoom\n	Frame	pixels\n" to:FOVData

		-- lights				
			if (chkLight.checked AND ((classof obj)==light)) then 
				format "" to:lightData


	-- query object

		if isvalidnode obj then
		(
			for t = spnAnimFrom.value to spnAnimTo.value do
			(
				at time t
				(
					if (spnAnimTo.value-spnAnimFrom.value==0) OR rdoAnimRange.state==1 then f=""
					else f=t
					in coordsys #world
					(

				-------------------------------------------------------------------------------
				-- object

					-------------------------------------------------------------------------------
					-- position
						if chkPos.checked then
						(
						-- data
							px=getVal obj.pos.x
							py=getVal obj.pos.y
							pz=getVal obj.pos.z
						-- format
							format "	%	%	%	%\n" f px -pz py to:posData
						)

					-------------------------------------------------------------------------------
					-- rotation
						if chkRot.checked AND (classof obj)!=Targetcamera then
						(
						-- data
							in coordsys mxYUP rot=obj.rotation as eulerangles
							rx=getVal rot.x
							ry=getVal rot.y
							rz=getVal rot.z
						-- format
							format "	%	%	%	%\n" f -rx ry rz to:rotData
						)

					-------------------------------------------------------------------------------
					-- scale
						if chkScale.checked then
						(
						-- data
							sx=getVal obj.scale.x
							sy=getVal obj.scale.y
							sz=getVal obj.scale.z
						-- format
							format "	%	%	%	%\n" f sx sz sy to:scaleData
						)
		
				-------------------------------------------------------------------------------
				-- camera data

					-------------------------------------------------------------------------------
					-- FOV
						if chkCam.checked AND (superclassof obj)==camera then
						(
						-- data
							--fov=getVal obj.fov
							fov=(spnCompHeight.value/2)/(tan (obj.fov/2))
						-- format
							format "	%	%\n" f fov to:FOVData
						)

				-------------------------------------------------------------------------------
				-- targetted objects

						if (chkCam.checked OR chkLight.checked) AND obj.target!=undefined then
						(
						-- data
							px=getVal obj.target.pos.x
							py=getVal obj.target.pos.y
							pz=getVal obj.target.pos.z
						-- format
							format "	%	%	%	%\n" f px -pz py to:targData
						)


		
					-------------------------------------------------------------------------------
					-- light data
						-- data
						-- format
							--format "	%	%	%	%\n" f px -pz py to:lightData
				)
			)
		)


		-- final data gathering
			str=stringstream ""
			data= stringstream ""
			format "%	%	%	%	%	%\n"	(posData as string) (rotData as string) (scaleData as string) (targData as string) (FOVData as string) (lightData as string) to:data
			data = data as string

--setClipboardText data

format "Adobe After Effects % Keyframe Data

	Units Per Second	%
	Source Width	%
	Source Height	%
	Source Pixel Aspect Ratio	1
	Comp Pixel Aspect Ratio	1

%
End of Keyframe Data\n" ddAEVersion.selected framerate spnCompWidth.value spnCompHeight.value data to:str

		-- export data
			clearListener()
			format "%" (str as string)
--			format "%" (data as string)
/*
			if setClipboardText == undefined then
			(
				clearListener()
				format "%" (str as string)
			)
			else setClipboardText (str as string)
*/

		)
	)


)
if AEFloater != undefined then closerolloutfloater AEFloater
	AEFloater = newRolloutFloater "After Effects Data Exporter" 244 366 250 100
addRollout ro1 AEFloater

