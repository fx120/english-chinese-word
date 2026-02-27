define(['jquery', 'bootstrap', 'backend'], function ($, undefined, Backend) {

    var Controller = {
        index: function () {
            $('#select-all').on('change', function () {
                $('.list-checkbox').prop('checked', $(this).is(':checked'));
            });
            $('#btn-export-selected').on('click', function () {
                var ids = [];
                $('.list-checkbox:checked').each(function () {
                    ids.push($(this).val());
                });
                if (ids.length === 0) {
                    Toastr.error('请至少选择一个词表');
                    return;
                }
                $('#list-ids').val(ids.join(','));
                $('#export-all').val('0');
                $('#export-form').submit();
            });
            $('#btn-export-all').on('click', function () {
                $('#export-all').val('1');
                $('#export-form').submit();
            });
        }
    };

    return Controller;
});
