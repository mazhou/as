package lee.projects.player.view.panels{
	import lee.projects.player.view.panels.BasePanel;
	import flash.display.Sprite;
	import flash.display.SimpleButton;
	import flash.events.MouseEvent;

	public class HomePanel extends BasePanel {
		public function HomePanel(skin:Sprite) {
			addChildrenFrom(skin);
		}
	}
}