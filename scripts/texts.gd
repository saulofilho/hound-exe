class_name Texts
## Todo texto visível, em português e inglês.
##
## `chave` é a versão de teclado; `chave_pad`, quando existe, é a de controle
## (a Steam exige que a tela só mostre botões de controle quando ele está em uso).

const LANGUAGES := ["pt", "en"]

const DATA := {
	"language_name": ["PORTUGUÊS", "ENGLISH"],

	"room_c_drive": ["C:\\", "C:\\"],
	"room_docs": ["C:\\Documentos", "C:\\Documents"],
	"room_downloads": ["C:\\Downloads", "C:\\Downloads"],
	"room_trash": ["C:\\Lixeira", "C:\\Trash"],
	"room_images": ["C:\\Imagens", "C:\\Pictures"],
	"room_gallery": ["C:\\Galeria", "C:\\Gallery"],
	"room_temp": ["C:\\Temp", "C:\\Temp"],
	"room_installers": ["C:\\Setup", "C:\\Setup"],
	"room_system32": ["C:\\System32", "C:\\System32"],
	"room_drivers": ["C:\\Drivers", "C:\\Drivers"],
	"room_ghost": ["C:\\Lixeira\\~fantasma.tmp", "C:\\Trash\\~ghost.tmp"],
	"boss_file": ["~fantasma.tmp", "~ghost.tmp"],
	"icon_docs": ["Documentos", "Documents"],
	"icon_downloads": ["Downloads", "Downloads"],
	"icon_trash": ["Lixeira", "Trash"],

	"hud_life": ["VIDA", "HP"],
	"hud_sniff": ["FARO", "SNIFF"],
	"hud_time": ["TEMPO %02d", "TIME %02d"],
	"hud_bugs": ["BUGS %d", "BUGS %d"],

	"hint_side": [
		"{left}/{right} anda · {jump} pula · {shoot} atira · {sniff} fareja · Esc pausa",
		"{left}/{right} move · {jump} jump · {shoot} shoot · {sniff} sniff · Esc pause",
	],
	"hint_side_pad": [
		"{jump} pula · {shoot} atira · {sniff} fareja · {map} mapa · Menu pausa",
		"{jump} jump · {shoot} shoot · {sniff} sniff · {map} map · Menu pause",
	],
	"hint_arena": [
		"{up}/{left}/{down}/{right} anda · mouse mira · {shoot} atira · {dash} dash",
		"{up}/{left}/{down}/{right} move · mouse aim · {shoot} shoot · {dash} dash",
	],
	"hint_arena_pad": [
		"Esquerdo anda · direito mira · {shoot} atira · {dash} dash",
		"Left stick move · right stick aim · {shoot} shoot · {dash} dash",
	],
	"boss_intro": [
		"ARQUIVO FANTASMA\nFareje para torná-lo sólido, ou espere ele bater.",
		"GHOST FILE\nSniff to make it solid, or wait for it to crash.",
	],
	"boss_copies": [
		"O arquivo criou cópias.\nAgora só o faro acerta o original.",
		"The file made copies.\nOnly sniffing can hit the original now.",
	],
	"boss_need_sniff": [
		"O tiro atravessa. Segure {sniff} e atire no original.",
		"Shots pass through. Hold {sniff} and shoot the original.",
	],
	"wall_smells": [
		"Esta parede cheira estranho.\nSegure {sniff} para farejar.",
		"This wall smells odd.\nHold {sniff} to sniff.",
	],
	"wall_found": ["PASSAGEM REVELADA", "PASSAGE REVEALED"],
	"health_full": ["Vida cheia: o patch fica para depois.", "Full health: the patch stays for later."],
	"hold_restart": ["Segure R para reiniciar do ponto de restauração", "Hold R to restart from the restore point"],
	"hold_restart_pad": ["Use Menu para reiniciar do ponto de restauração", "Use Menu to restart from the restore point"],
	"arena_zones": ["Setores marcados vão corromper. Saia de cima!", "Marked sectors will corrupt. Step off them!"],
	"boss_down": ["ARQUIVO FANTASMA EXCLUÍDO\nregião limpa, saída aberta", "GHOST FILE DELETED\nregion clean, exit open"],
	"got_health": ["+1 VIDA", "+1 HP"],
	"got_dash": [
		"DASH INSTALADO · {dash}\natravessa lasers e vãos",
		"DASH INSTALLED · {dash}\ngoes through lasers and across gaps",
	],
	"got_restore": ["PONTO DE RESTAURAÇÃO CRIADO", "RESTORE POINT CREATED"],
	"folder_enter": ["{down} entra em %s", "{down} opens %s"],
	"folder_locked": ["atalho fechado", "shortcut closed"],
	"folder_shut": ["O atalho abre quando você vencer a quarentena de lá.", "The shortcut opens once you clear the quarantine there."],
	"clue_smells": ["Tem algo enterrado aqui.\nSegure {sniff} para farejar.", "Something is buried here.\nHold {sniff} to sniff."],
	"clue_dug": ["PISTA DESENTERRADA", "CLUE UNEARTHED"],
	"clue_got": ["PISTA %d DE %d\nA porta no fim da Lixeira pede todas.", "CLUE %d OF %d\nThe door at the end of the Trash needs them all."],
	"clue_all": ["TODAS AS PISTAS\nA porta no fim da Lixeira abriu.", "ALL CLUES FOUND\nThe door at the end of the Trash is open."],
	"door_needs": ["A porta exige %d pistas. Você tem %d.", "The door needs %d clues. You have %d."],
	"secret_got": ["BACKUP SECRETO %d DE %d\no faro dura mais", "SECRET BACKUP %d OF %d\nsniffing lasts longer"],
	"quarantine": ["QUARENTENA\nlimpe a área para sair", "QUARANTINE\nclear the area to leave"],
	"quarantine_clear": ["QUARENTENA ENCERRADA", "QUARANTINE LIFTED"],
	"region_clean": ["Região limpa.", "Region clean."],
	"save_failed": ["NÃO FOI POSSÍVEL SALVAR O PROGRESSO", "COULD NOT SAVE YOUR PROGRESS"],
	"arena_won": ["PROCESSO CONCLUÍDO\n\nVoltando para a região...", "PROCESS COMPLETE\n\nReturning to the region..."],
	"death_side": [
		"TELA AZUL\n\nUm erro fatal ocorreu no hound.exe.\nR volta ao ponto de restauração.",
		"BLUE SCREEN\n\nA fatal error occurred in hound.exe.\nPress R to return to the restore point.",
	],
	"death_side_pad": [
		"TELA AZUL\n\nUm erro fatal ocorreu no hound.exe.\nMenu volta ao ponto de restauração.",
		"BLUE SCREEN\n\nA fatal error occurred in hound.exe.\nPress Menu to return to the restore point.",
	],
	"death_top": [
		"TELA AZUL\n\nO processo hound.exe parou de responder.\nR volta ao ponto de restauração.",
		"BLUE SCREEN\n\nhound.exe stopped responding.\nPress R to return to the restore point.",
	],
	"death_top_pad": [
		"TELA AZUL\n\nO processo hound.exe parou de responder.\nMenu volta ao ponto de restauração.",
		"BLUE SCREEN\n\nhound.exe stopped responding.\nPress Menu to return to the restore point.",
	],

	"explorer_title": ["Explorer - ", "Explorer - "],
	"explorer_legend": [
		"ponto de restauração · {map} fecha",
		"restore point · {map} closes",
	],
	"title_saved": ["Progresso salvo · volta em ", "Saved · resumes at "],
	"title_clean": [" · região limpa", " · region clean"],
	"title_bad_save": ["O save não pôde ser lido.", "The save could not be read."],
	"title_replace": ["Começar de novo substitui o progresso salvo.", "Starting over replaces your saved progress."],
	"title_keys": ["setas ou W/S escolhem · Enter confirma", "arrows or W/S choose · Enter confirms"],
	"title_keys_pad": ["direcional escolhe · A confirma · B volta", "D-pad chooses · A confirms · B back"],

	"menu_continue": ["CONTINUAR", "CONTINUE"],
	"menu_new": ["NOVO JOGO", "NEW GAME"],
	"menu_options": ["OPÇÕES", "OPTIONS"],
	"menu_quit": ["SAIR", "QUIT"],
	"menu_cancel": ["CANCELAR", "CANCEL"],
	"menu_erase": ["APAGAR E COMEÇAR", "ERASE AND START"],
	"menu_restore": ["VOLTAR AO PONTO DE RESTAURAÇÃO", "RETURN TO RESTORE POINT"],
	"menu_title": ["TELA DE TÍTULO", "TITLE SCREEN"],
	"menu_quit_game": ["SAIR DO JOGO", "QUIT GAME"],
	"menu_back": ["VOLTAR", "BACK"],
	"menu_credits": ["CRÉDITOS", "CREDITS"],
	"menu_explore": ["CONTINUAR EXPLORANDO", "KEEP EXPLORING"],

	"opt_music": ["MÚSICA", "MUSIC"],
	"opt_effects": ["EFEITOS", "EFFECTS"],
	"opt_language": ["IDIOMA", "LANGUAGE"],
	"opt_fullscreen": ["TELA CHEIA", "FULLSCREEN"],
	"opt_shake": ["TREMOR DE TELA", "SCREEN SHAKE"],
	"on": ["SIM", "ON"],
	"off": ["NÃO", "OFF"],
	"menu_controls": ["CONTROLES", "CONTROLS"],
	"ctrl_device": ["CONTROLES", "CONTROLS"],
	"ctrl_key": ["TECLADO", "KEYBOARD"],
	"ctrl_pad": ["GAMEPAD", "GAMEPAD"],
	"ctrl_reset": ["RESTAURAR PADRÃO", "RESET TO DEFAULT"],
	"ctrl_press_key": ["aperte a tecla... (Esc cancela)", "press a key... (Esc cancels)"],
	"ctrl_press_key_pad": ["aperte a tecla... (Menu cancela)", "press a key... (Menu cancels)"],
	"ctrl_press_pad": ["aperte o botão... (Menu cancela)", "press a button... (Menu cancels)"],
	"act_left": ["Esquerda", "Left"],
	"act_right": ["Direita", "Right"],
	"act_up": ["Cima / mirar", "Up / aim"],
	"act_down": ["Baixo / entrar", "Down / enter"],
	"act_jump": ["Pular", "Jump"],
	"act_shoot": ["Atirar", "Shoot"],
	"act_dash": ["Dash", "Dash"],
	"act_sniff": ["Farejar", "Sniff"],
	"act_map": ["Explorer", "Explorer"],
	"options_heading": ["Opções", "Options"],

	"pause_heading": ["Processo pausado", "Process paused"],
	"pause_saved": [
		"O progresso é salvo sozinho. Ao voltar, o cão\naparece no último ponto de restauração.",
		"Progress saves by itself. When you return, the\nhound wakes at the last restore point.",
	],
	"pause_no_save": [
		"Salvamento desligado:\nsala aberta sem passar pelo título.",
		"Saving is off:\nroom opened without the title screen.",
	],

	"ending_stats": ["Tempo %s · mortes %d · segredos %d/%d", "Time %s · deaths %d · secrets %d/%d"],
	"ending_heading": ["Área de trabalho limpa", "Desktop clean"],
	"ending_text": [
		"Você excluiu o Arquivo Fantasma.\nEste é o fim desta versão. Obrigado por jogar!",
		"You deleted the Ghost File.\nThis is the end of this version. Thanks for playing!",
	],

	"credits_heading": ["Créditos", "Credits"],
	"credits_text": [
		"HOUND.EXE %s\n\num jogo de saulofilho\ncom o cão do scopehound\n\nfeito com Godot Engine\ncopyright Juan Linietsky, Ariel Manzur\ne colaboradores do Godot Engine\n\nlicenças: THIRD_PARTY_NOTICES.txt",
		"HOUND.EXE %s\n\na game by saulofilho\nstarring the scopehound hound\n\nmade with Godot Engine\ncopyright Juan Linietsky, Ariel Manzur\nand Godot Engine contributors\n\nlicenses: THIRD_PARTY_NOTICES.txt",
	],
}


static func lookup(key: String, language: String, pad: bool) -> String:
	var index := maxi(LANGUAGES.find(language), 0)
	if pad and DATA.has(key + "_pad"):
		key += "_pad"
	return DATA[key][index]
