dependencies ={
    layers:  [
        {
        name: "dojo-ps-toolkit.js",
        dependencies: [
            //NOTE: Do NOT include dojo.date.locale or date formatting breaks
            "dojo._base.connect",
            "dojo.parser",
            "dijit._base",
            "dijit.Dialog",
            "dijit.TooltipDialog",
            "dijit.ProgressBar",
            "dijit.form.Button",
            "dijit.form.CheckBox",
            "dijit.form.ComboButton",
            "dijit.form.DropDownButton",
            "dijit.form.FilteringSelect",
            "dijit.form.Form",
            "dijit.form.NumberTextBox",
            "dijit.form.RadioButton",
            "dijit.form.TextBox",
            "dijit.form.ValidationTextBox",
            "dojo.data.ItemFileReadStore",
            "dojox.data.CsvStore",
            "dojox.validate.regexp",
        ]
        }
    ],
    prefixes: [
        [ "dijit", "../dijit" ],
        [ "dojox", "../dojox" ],
    ]
};

