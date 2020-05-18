" I don't yet have any idea what to put here. I should probably use it to make
" the Gradle plugin load lazily; no need to waste users' time with starting a
" JVM process every time.
let gradle#javaprg = 'java'

" ===[ VARIABLES ]=============================================================
" Initialize the channel, do not overwrite existing value (possible if the
" script has been sourced multiple times)
call extend(s:, {'job_id': 0}, 'keep')

" Path to binary
let s:root = resolve(expand('<sfile>:p:h').'/..')
let s:bin = s:root.'/build/install/gradle.nvim/bin/gradle.nvim'
let s:hasConnected = v:false

" ===[ CALLBACKS ]=============================================================
function! s:on_stderr(chan_id, data, name)
    " echom printf('%s: %s', a:name, string(a:data))
endfunction


" ===[ SETUP ]=================================================================
" Entry point. Initialise RPC
function! s:connect()
    let l:job_id = s:initRpc(s:job_id)

    if l:job_id == 0
        echoerr "Gradle: cannot start RPC process"
    elseif l:job_id == -1
        echoerr "Gradle: RPC process is not executable"
    else
        " Mutate our job Id variable to hold the channel ID
        let s:job_id = l:job_id
        let s:hasConnected = v:true
    endif
endfunction

function! s:getCommandEnv()
    let javaHome = get(g:, 'GradleNvimJavaHome', v:null)
    if javaHome is v:null
        return {}
    endif
    return {'JAVA_HOME': javaHome}
endfunction

" Initialize RPC
function! s:initRpc(job_id)
    if a:job_id == 0
        let l:opts = {'rpc': v:true, 'on_stderr': funcref('s:on_stderr'), 'env': s:getCommandEnv()}
        let jobid = jobstart(['sh', s:bin], l:opts)
        return jobid
    else
        return a:job_id
    endif
endfunction

function! gradle#handshake()
    if s:hasConnected
        echo rpcrequest(s:job_id, 'handshake')
    endif
    echo "NOT INSTALLED"
endfunction

" TODO - make this async somehow?
function! gradle#getTasks(path)
    if s:hasConnected
        return rpcrequest(s:job_id, 'get-tasks', a:path)
    endif
    return []
endfunction

function! s:onInstallCompleted(jobId, exitCode, eventType)
    if a:exitCode == 0
        call s:connect()
        echo "gradle.vim installed successfully"
    else
        echoerr "gradle.vim failed to install!  Please run `gradle install` manually to debug."
    endif
endfunction

if filereadable(s:bin)
    call s:connect()
else
    if input("Plugin gradle.nvim not initialized!  Initialize now? (y/n)") == 'y'
        call jobstart(['gradle', 'install'], {
            \ 'cwd': s:root,
            \ 'on_exit': function('s:onInstallCompleted'),
            \ 'env': s:getCommandEnv()})
    endif
endif

