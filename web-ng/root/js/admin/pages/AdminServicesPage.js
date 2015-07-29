// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostStore, HostServicesComponent and HostInfoComponent all load before this.

var AdminServicesPage = { 
    adminServicesTopic: 'store.change.host_services',
    serviceList: ['bwctl', 'owamp', 'ndt', 'npad'],
    latencyServices: ['owamp'],
    updateURL: '/toolkit-ng/admin/services/host.cgi?method=update_enabled_services',
};

AdminServicesPage.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe(AdminServicesPage.adminServicesTopic, AdminServicesPage._setEnabledServices);
    $('#select_bandwidth_services').click('bandwidth', AdminServicesPage.selectServices);
    $('#select_latency_services').click('latency', AdminServicesPage.selectServices);
//    $('#select_all_services').click();
//    $('#select_no_services').click();

    $('input:checkbox').filter(function() {
         return this.id.match(/services_.+_cb$/);    
    }).change(AdminServicesPage._showSaveBar);
    $('#admin_info_save_button').click( AdminServicesPage._save );

};


AdminServicesPage._setEnabledServices = function(topic) {
    var data = HostStore.getHostServices();
    $('#loading-modal').foundation('reveal', 'close');
    
    var serviceList = AdminServicesPage.serviceList;
    for(var i in data.services) {
        var service = data.services[i];
        if (jQuery.inArray(service.name, serviceList) > -1) {
            var service_id = 'services_' + service.name + '_cb';
            var service_el = $('#' + service_id);
            var service_cont_el = $('#enabled_services_fields .services_' + service.name);
            var checked = service.enabled;
            service_el.prop( "checked", checked );
            if (typeof service.is_installed != "undefined" && service.is_installed == '0') {
                service_el.addClass("uninstalled");
                service_cont_el.addClass("uninstalled");
                service_el.prop("disabled", true);
            } else {
                service_el.removeClass("uninstalled");                
                service_cont_el.removeClass("uninstalled");
                service_el.prop("disabled", false);
            }
        } 

    }

};

AdminServicesPage.selectServices = function(arg) {
    var type = arg.data;
    arg.preventDefault();
    var serviceList = AdminServicesPage.serviceList;
    var latencyServices = AdminServicesPage.latencyServices;
    for (var i in serviceList) {
        var service = serviceList[i];
        var serviceID = 'services_' + service + '_cb';
        if (type == 'latency') {
            if ( jQuery.inArray(service, latencyServices) > -1 ) {
                AdminServicesPage._checkService(serviceID, true);
            } else {
                AdminServicesPage._checkService(serviceID, false);
            }            
        } else {
            if ( jQuery.inArray(service, latencyServices) > -1 ) {
                AdminServicesPage._checkService(serviceID, false);
            } else {
                AdminServicesPage._checkService(serviceID, true);
            }            
        }
    }
    AdminServicesPage._showSaveBar();
    
};

AdminServicesPage._save = function() {
    var data = {};
    var services = AdminServicesPage.serviceList;
    for (var i in services) {
        var service = services[i];
        var el = $('#services_' + service + '_cb');
        var value = (el.prop("checked") ? 1 : 0);
        data[service] = value;
    }
    $.ajax({
        url: AdminServicesPage.updateURL,
        type: 'POST',
        data: data,
        contentType: 'application/json',
        // TODO: handle success/failure better
        success: function(result) {
            console.log("success");
        },
        error: function(jqXHR, textStatus, errorThrown) {
            console.log("error: object: ", jqXHR, "textStatus", textStatus, "errorThrown", errorThrown);
        }
    });

};

AdminServicesPage._checkService = function(serviceID, checked) {
    var el =  $('#' + serviceID);
    if (! el.prop("disabled") ) {
        el.prop("checked", checked);
    } else {
        el.prop("checked", false);
    }
};

AdminServicesPage.clearServices = function() {
    $('input:checkbox').filter(function() {
         return this.id.match(/services_.+_cb$/);    
    })
    .prop("checked", false);
};

AdminServicesPage._showSaveBar = function() {
    $(".sticky-bar--unsaved").fadeIn("fast");    
};

AdminServicesPage.initialize();
