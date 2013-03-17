//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require jquery.ui.slider
//= require jquery.ui.sortable
//= require jquery.ui.datepicker
//= require soundmanager
//= require history
//= require util
//= require player

# Generic namespace
Ph = {}

$ ->
  
  # Shun IE
  alert 'IE!' unless history.pushState
  
  # Instantiate stuff
  Ph.Util         = new Util
  Ph.Player       = new Player(Ph.Util)
  
  # Page elements
  $notice         = $ '.feedback_notice'
  $alert          = $ '.feedback_alert'
  $ajax_overlay   = $ '#ajax_overlay'
  $page           = $ '#page'
  
  ###############################################
  # ON AJAX SUCCESS
  ###############################################
  $(document).ajaxSuccess( ->
    
    # Sortable playlist AJAX load
    $('#current_playlist').sortable({
      placeholder: "ui-state-highlight",
      update: ->
        Ph.Util.updateCurrentPlaylist 'Track moved in playlist'
    })
    
    # Search datepicker
    $('#search_date').datepicker({
      dateFormat: "yy-mm-dd",
      changeYear: true,
      changeMonth: true,
      yearRange: '1987:2013',
      showOtherMonths: true,
      selectOtherMonths: true
    })
    
    # Highlight the currently playing track
    Ph.Player.highlightActiveTrack()
    
  )

  ###############################################
  # Prepare history.js
  ###############################################
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    State = History.getState()
    History.log State.data, State.title, State.url
  History.Adapter.bind window, 'popstate', ->   
    state = window.History.getState()
    if state.data.href != undefined and !Ph.Util.page_init
      $ajax_overlay.css 'visibility', 'visible'
      $page.html ''
      $page.load(
        state.data.href, (response, status, xhr) ->
          Ph.DOM
          alert("ERROR\n\n"+response) if status == 'error'
          $ajax_overlay.css 'visibility', 'hidden'
      )
      # Report href to Google Analytics
      _gaq.push([ '_trackPageview', state.data.href ]); 
      
  # Click a link to load context via ajax
  $(document).on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      Ph.Util.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      false
  
  ###############################################
  # Handle feedback on DOM load
  ###############################################
  if $notice.html() != ''
    $notice.show 'slide'
    setTimeout( ->
      $notice.hide 'slide'
    , 3000)
  else
    $notice.hide()
  if $alert.html() != ''
    $alert.show 'slide'
    setTimeout( ->
      $alert.hide 'slide'
    , 3000)
  else
    $alert.hide()
  
  $('#player_feedback').hide()
  
  ###############################################
  # Auto-play or scroll to and play anchor
  ###############################################
  soundManager.onready( ->
    if $('#app_data').data('autoplay') == true
      Ph.Player.playTrack $('.playable_track').first().data('id')
    else if anchor_name = $('#app_data').data 'anchor'
      if $el = $('li[data-anchor='+anchor_name+']')
        $('html,body').animate({scrollTop: $el.offset().top - 300}, 500)
        Ph.Player.playTrack $el.data('id')
  )

  ###############################################
  # DOM interactions
  ###############################################
  
  # Search datepicker
  $('#search_date').datepicker({
    dateFormat: "yy-mm-dd",
    changeYear: true,
    changeMonth: true,
    yearRange: '1987:2013',
    showOtherMonths: true,
    selectOtherMonths: true
  })
  
  # Focus => remove other value
  $(document).on 'focus', '#search_term', (e) ->
    $('#search_date').val ''
  $(document).on 'focus', '#search_date', (e) ->
    $('#search_term').val ''
  
  # Submit search
  $(document).on 'click', '#search_submit', (e) ->
    Ph.Util.navigateTo '/search?date='+$('#search_date').val()+'&term='+$('#search_term').val()

  ###############################################
  
  # Sortable playlist DOM load
  $('#current_playlist').sortable({
    placeholder: "ui-state-highlight",
    update: ->
      Ph.Util.updateCurrentPlaylist 'Track moved in playlist'
  })
  
  # Remove track from playlist
  $(document).on 'click', '.playlist_remove_track', (e) ->
    track_id = $(this).parents('li').data('id')
    $(this).parents('li').remove()
    if $('#current_playlist').children('li').size() == 0
      Ph.Util.followLink $('#clear_playlist')
      Ph.Player.stopAndUnload()
    else
      Ph.Util.updateCurrentPlaylist 'Track removed from playlist'
      Ph.Player.stopAndUnload track_id
  
  # Add track to playlist
  $(document).on 'click', '.playlist_add_track', (e) ->
    track_id = $(this).data('id')
    $.ajax({
      type: 'post',
      url: '/add-track',
      data: { 'track_id': track_id}
      success: (r) ->
        if r.success
          Ph.Util.feedback { 'msg': 'Track added to playlist' }
        else
          Ph.Util.feedback { 'type': 'alert', 'msg': r.msg }
    })
  
  # Add show to playlist
  $(document).on 'click', '.playlist_add_show', (e) ->
    show_id = $(this).data('id')
    $.ajax({
      type: 'post',
      url: '/add-show',
      data: { 'show_id': show_id}
      success: (r) ->
        if r.success
          Ph.Util.feedback { 'msg': r.msg }
        else
          Ph.Util.feedback { 'type': 'alert', 'msg': r.msg }
    })
  
  # Clear playlist should stop and unload current sound
  $(document).on 'click', '#clear_playlist', (e) ->
    Ph.Player.stopAndUnload()
  
  # Playlist Option change
  $(document).on 'change', '.playlist_option', (e) ->
    $.ajax({
      type: 'post',
      url: '/submit-playlist-options',
      data: {
        'loop': $('#loop_checkbox').prop('checked'),
        'randomize': $('#randomize_checkbox').prop('checked')
      }
      success: (r) ->
        if r.success
          Ph.Util.feedback { 'msg': 'Playlist options saved' }
        else
          Ph.Util.feedback { 'type': 'alert', 'msg': r.msg }
    })
  
  ###############################################
  
  # Click a track to play it
  $(document).on 'click', '.playable_track', (e) ->
    Ph.Player.resetPlaylist $(this).data('id')
    Ph.Player.playTrack $(this).data('id')
  
  # Click Play in a context menu to play the track
  $(document).on 'click', '.context_play_track', (e) ->
    Ph.Player.resetPlaylist $(this).data('id')
    Ph.Player.playTrack $(this).data('id')

  # Click the Play/Pause button
  $(document).on 'click', '#playpause', (e) ->
    Ph.Player.togglePause()
  
  # Click the Previous button
  $(document).on 'click', '#previous', (e) ->
    Ph.Player.previousTrack()

  # Click the Next button
  $(document).on 'click', '#next', (e) ->
    Ph.Player.nextTrack()
    
  # Scrubber (jQuery UI slider)
  $('#scrubber').slider({
    animate: 'fast',
    range: 'min',
    max: 100,
    value: 0,
    start: ->
      Ph.Player.startScrubbing()
    stop: ->
      Ph.Player.stopScrubbing()
    slide: ->
      Ph.Player.moveScrubber()
  })
  
  # Volume slider (jQuery UI slider)
  $('#volume_slider').slider({
    animate: 'fast',
    range: 'min',
    max: 100,
    value: 100,
    slide: ->
      Ph.Player.updateVolumeSlider $(this).slider('value')
  })
  
  # Loop / Randomize controls
  $(document).on 'click', '#loop_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
  $(document).on 'click', '#randomize_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
    
  # Toggle mute
  $(document).on 'click', '#volume_icon', (e) ->
    Ph.Player.toggleMute()
    e.stopPropagation()
  
  ###############################################

  # Click to download an individual track
  $(document).on 'click', 'a.download', ->
    data_url = $(this).data('url')
    $.ajax({
      url: '/user-signed-in',
      success: (r) ->
        if r.success
          location.href = data_url if data_url
        else
          Ph.Util.feedback { 'type': 'alert', 'msg': 'You must sign in to download MP3s' }
    })
  
  # Click to download a set of tracks
  $(document).on 'click', 'a.download-album', ->
    Ph.Util.requestAlbum $(this).data('url'), true
    
  # Stop polling server when download modal is hidden
  $('#download_modal').on 'hidden', ->
    Ph.Util.StopDownloadPoller

  ###############################################
  
  # Like tooltip
  $('.likes_large a').tooltip({
    placement: 'bottom',
    delay: { show: 500, hide: 0 }
  })
  $('.likes_small > a').tooltip({
    delay: { show: 500, hide: 0 }
  })
  
  # Click a Like to submit to server
  $(document).on 'click', '.like_toggle', ->
    $this = $(this)
    $.ajax({
      type: 'post',
      url: '/toggle-like',
      data: { 'likable_type': $this.data('type'), 'likable_id': $this.data('id') }
      dataType: 'json',
      success: (r) ->
        if r.success
          if r.liked then $this.addClass('liked') else $this.removeClass('liked')
          Ph.Util.feedback({ 'msg': r.msg })
          $this.siblings('span').html(r.likes_count)
        else
          Ph.Util.feedback({ 'type': 'alert', 'msg': r.msg })
    })
  
  # Rollover year to reveal number of shows
  $(document).on 'mouseover', '.year_list > li', ->
    $(this).find('h2').css 'visibility', 'visible'
  $(document).on 'mouseout', '.year_list > li', ->
    $(this).find('h2').css 'visibility', 'hidden'

  # Rollover item list to reveal context button
  $(document).on 'mouseover', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'visible'
  $(document).on 'mouseout', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'hidden'

  # Rollover header to reveal context button
  $(document).on 'mouseover', '#header', ->
    $(this).find('.btn_context').css 'visibility', 'visible'
  $(document).on 'mouseout', '#header', ->
    $(this).find('.btn_context').css 'visibility', 'hidden'
    
  # Follow links in .year_list
  $(document).on 'click', '.year_list > li', ->
    Ph.Util.followLink $(this).find 'a'
  
  # Follow h1>a links in .item_list.clickable > li
  $(document).on 'click', '.item_list > li', ->
    if $(this).parent('ul').hasClass 'clickable'
      Ph.Util.followLink $(this).children('h2').find 'a'
  
  # Share links bring up a modal to display a url
  $(document).on 'click', '.share', ->
    $('#share_url').html("<p>"+$('#app_data').data('base-url')+$(this).data('url')+"</p>")
    $('#share_modal').modal('show')
    