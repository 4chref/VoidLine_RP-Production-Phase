# KuzQuality Lasers (Free) | Docs

___

## Intro | Entity types

### Laser
A line between two points. Detects anything which breaks the line between said points.
When the line between the points is broken, events or callbacks can be triggered.
Lasers can be oscillating between two end points as well. The color and opacity of the lasers can be adjusted
dynamically. 

___

## Usage | Basics

To call the exported functions, use the FiveM exports.

**Example**
`exports['kq_security']:CreateLaser(name, data)`

___
## Basic usage | Lasers

### Laser properties
> - origin - vector3*
>   -  The starting point of the laser
> - endPoint - vector3*
>   - The end point of the laser
> - maxLength - float*
>   - Max length of the laser
> - damage - int
>   - Amount of damage that the laser should deal
> - ragdoll - boolean
>   - Whether the laser should make players ragdoll on hit
> - handler - function/callback
>   - Callback function triggered upon laser trigger
> - triggers - table
>   - A custom table containing events which will be triggered upon laser trigger
>   - See below for an example table
> - alarms - table
>   - Table with the names of the alarms which the laser will trigger
> - cooldown - int
>   - Cooldown duration in milliseconds; aka, time between each laser trigger event
> - active - boolean
>   - Whether the laser should be active upon creation
>   
> (* = Required)

**Example:**

```lua
local data = {
    origin = vector3(-924.9017, -2946.101, 13.738),
    endPoint = vector3(-920.802, -2949.351, 14.820),

    maxLength = 15.0,

    damage = 5,
    ragdoll = true,

    alarms = { 'lsia' },

    triggers = {
        {
            event = 'kq_security:dispatch:client:trigger',
            type = 'client',
            parameters = {
                title = 'Laser tripped!',
                message = 'a security laser at the LSIA has been tripped.',
                jobs = { 'police' },
            },
        }
    }
},
```

### Laser event triggers
As seen above, lasers can trigger events upon trigger.
See below to find out more about the structure of these events
> Triggers is a table of multiple event triggers. These should contain the following values:
> - event - string
>   - the event name which should be triggered
> - type - string - options: server, client
>   - The network type of the event
> - parameters - table
>   - Parameters which will be sent in the event as its parameters

**Example:**
```lua
data.triggers = {
    {
        event = 'kq_security:dispatch:client:trigger',
        type = 'client',
        parameters = {
            title = 'Laser tripped!',
            message = 'a security laser at the LSIA has been tripped.',
            jobs = { 'police' },
        },
    }
}
```


### Create
Used for creating a new laser
> `CreateLaser(name, data)`
>
> **Arguments**
> - Name - String - Unique key of the laser
> - Data - Table - Table containing all laser properties
> 
> **Returns**
> - Laser object - This object can be used to manipulate the laser after its creation

### Getting the list of all lasers
> `GetAllLasers()`
>
> **Returns**
> - Table of all laser objects

### Getting a laser by its name
> `GetLaserByName(name)`
>
> **Arguments**
> - Name - String - Name of the laser you're trying to retrieve
> 
> **Returns**
> - Laser object

### Getting the nearest laser
> `GetNearestLaser(coords, maxDistance)`
> 
> **Arguments**
> - Coords - vector3 - The location from which you're trying to find the nearest laser
> - MaxDistance - float - The maximum distance in meters in which you're looking for a laser
> 
> **Returns**
> - Laser object
> - Distance to the laser
> > Returns `nil` when nothing is found
___

## Advanced usage | Lasers
Once you have created a laser you are able to modify it on the go.

**Example:**
```lua
-- Create a new laser
local laser = exports['kq_security']:CreateLaser('myLaser', laserData)

-- Disable the laser
laser.SetActive(false)
```

### Laser functions
> `Delete()`
> 
> Deletes the laser

> `SetActive(active)`
> 
> Sets the lasers active state (true or false)

> `SetHandler(callback)`
> 
> Sets the trigger handler to a new callback function

> `SetTrigger(triggerTable)`
> 
> Sets the trigger to a new trigger table (see basic usage for table example)

> `SetOpacity(newOpacity)`
> 
> Sets the laser opacity to a new value without affecting its color

> `SetCooldown(newCooldown)`
> 
> Changes the laser trigger cooldown

___


## Full usage example | Laser
```lua
local laserData = {
    origin = vector3(-924.9017, -2946.101, 13.738),
    endPoint = vector3(-920.802, -2949.351, 14.820),
    
    maxLength = 15.0,

    damage = 5,
    ragdoll = true,

    alarms = {
        'lsia'
    },
    
    triggers = {
        {
            event = 'kq_security:dispatch:client:trigger',
            type = 'client',
            parameters = {
                title = 'Laser tripped!',
                message = 'a security laser at the LSIA has been tripped.',
                jobs = { 'police' },
            },
        }
    }
}

local laser = exports['kq_lasers']:CreateLaser('myUniqueLaserName', laserData)

--- Making the laser flash on and off (obviously, this is just an example)
CreateThread(function()
    local state = true
    while true do
        -- Flip the state
        state = not state
        
        -- Set the laser state
        laser.SetActive(state)
        
        -- Wait 1 second
        Citizen.Wait(1000)
    end
end)
```
