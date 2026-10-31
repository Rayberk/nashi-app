export function resetDemoHistory(state, revoke) {
  for (const url of state.urls) revoke(url);
  state.urls.clear();
  state.library = [];
  state.shelf = [];
  state.float = {open:false, expanded:false, list:false, selected:[]};
}
