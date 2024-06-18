$(document).ready(function () {
  $('#show-closed').change(function () {
    var showClosed = $(this).is(':checked');

    if (showClosed) {
      $('.closed').show('slow');
    } else {
      $('.closed').hide('slow');
    }

    $('#filters').children('input[id^="toogle-"]').filter('input[id*="cerrado"]').each(function () {
      $(this).prop('checked', showClosed);
    });
  });

  $('#filters').children('input[id^="toogle-"]').change(function () {
    groupId = $(this).prop('id').replace('toogle-', '');

    if ($(this).is(':checked')) {
      $('#' + groupId).show('slow');
    } else {
      $('#' + groupId).hide('slow');
    }
  })
});