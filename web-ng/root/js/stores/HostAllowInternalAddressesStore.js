// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostAllowInternalAddressesStore = {
    hostAllowInternalAddresses: null,
    allowInternalAddressesTopic: 'store.change.host_in_add',
};

HostAllowInternalAddressesStore.initialize = function() {
    HostAllowInternalAddressesStore._retrieveInfo();
};

HostAllowInternalAddressesStore._retrieveInfo = function() {
    $.ajax({
            url: "services/host.cgi?method=get_allow_internal_addresses",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",            
            success: function (data) {
                HostAllowInternalAddressesStore.hostAllowInternalAddresses = data;
                Dispatcher.publish(HostAllowInternalAddressesStore.allowInternalAddressesTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
                
            }
        });
};

HostAllowInternalAddressesStore.getAllowInternalAddressesInfo = function() {
    return HostAllowInternalAddressesStore.allowInternalAddressesInfo;
};

HostAllowInternalAddressesStore.initialize();
