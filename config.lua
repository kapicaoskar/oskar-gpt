Config = {}

Config.OpenKey = 73
Config.OpenOptions = {
    ["gpt"] = {
        keyId = 73, -- if nil that can be opened only from trigger "client-gpt-tirex:openGpt"
    },
    ["dispatch"] = {
        keyId = 26, -- if nil that can be opened only from trigger "client-gpt-tirex:openDispatch"
    }
}

Config.JailSettings = {
    customJailSystem = {
        type = '', -- "client" or "server"
        trigger = '' -- type own trigger | client get (officerjob, bill, jailtime) | server get (target id, officerjob, bill, jailtime)
    },
    customBillSystem = {
        type = '', -- "client" or "server"
        trigger = '' -- type own trigger | client get (officerjob, bill, jailtime) | server get (target id, officerjob, bill, jailtime)
    },
}

Config.RadioExport = '-' -- type your own export what can return radio channel of officer using ssn as "v"

Config.JobName = {
    ["police"] = {
        toogle = true,
        notify = true,
        onDuty = 'police',
        offDuty = 'offpolice',
        menagmentGrade = 4,
    },
    ["sheriff"] = {
        toogle = false,
        notify = false,
        onDuty = 'police',
        offDuty = 'offpolice',
        menagmentGrade = 0,
    },
    ["doj"] = {
        toogle = false,
        notify = false,
        onDuty = 'police',
        offDuty = 'offpolice',
        menagmentGrade = 0,
    },
    ["fib"] = {
        toogle = false,
        notify = false,
        onDuty = 'police',
        offDuty = 'offpolice',
        menagmentGrade = 0,
    }
}

Config.UnitsType = {
    "SEU",
    "Merry",
    "Normal",
    "Eagle",
}
Config.MaxPatrolSlots = 4

Config.HelpCommand = {
    name = '911',
    helpText = ' Your content ',
    helpTextOfArgs = 'Type all of you need',
    maxOfficers = 7,
    reportsDurability = 5
}