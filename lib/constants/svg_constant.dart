class SvgConstant {
  static const String svgLogo = '''
<svg width="240" height="240" viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">
  <rect width="240" height="240" fill="#000"/>

  <g stroke="#ffffff" stroke-width="6" fill="none" stroke-linecap="round">
    <path d="M74 94 L74 81 L87 81">
      <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>
    </path>
    <path d="M166 94 L166 81 L153 81">
      <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>
    </path>
    <path d="M74 146 L74 159 L87 159">
      <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>
    </path>
    <path d="M166 146 L166 159 L153 159">
      <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>
    </path>
  </g>

  <circle cx="113" cy="141" r="5" fill="#FF6500">
    <animate attributeName="cy" values="141;99;141" dur="1.8s" repeatCount="indefinite"/>
    <animate attributeName="cx" values="113;110;113" dur="1.8s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;1;0" dur="1.8s" repeatCount="indefinite"/>
    <animate attributeName="r" values="5;2;5" dur="1.8s" repeatCount="indefinite"/>
  </circle>

  <circle cx="120" cy="141" r="6" fill="#FF9500">
    <animate attributeName="cy" values="141;89;141" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="cx" values="120;122;120" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;1;0" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="r" values="6;2;6" dur="2s" repeatCount="indefinite"/>
  </circle>

  <circle cx="127" cy="141" r="4" fill="#FF6500">
    <animate attributeName="cy" values="141;103;141" dur="1.5s" repeatCount="indefinite"/>
    <animate attributeName="cx" values="127;131;127" dur="1.5s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;1;0" dur="1.5s" repeatCount="indefinite"/>
    <animate attributeName="r" values="4;1;4" dur="1.5s" repeatCount="indefinite"/>
  </circle>

  <circle cx="117" cy="145" r="3" fill="#FFB347">
    <animate attributeName="cy" values="145;106;145" dur="2.2s" repeatCount="indefinite"/>
    <animate attributeName="cx" values="117;112;117" dur="2.2s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;0.8;0" dur="2.2s" repeatCount="indefinite"/>
    <animate attributeName="r" values="3;1;3" dur="2.2s" repeatCount="indefinite"/>
  </circle>

  <circle cx="125" cy="143" r="4" fill="#FF4500">
    <animate attributeName="cy" values="143;96;143" dur="1.6s" repeatCount="indefinite"/>
    <animate attributeName="cx" values="125;128;125" dur="1.6s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;0.9;0" dur="1.6s" repeatCount="indefinite"/>
    <animate attributeName="r" values="4;1;4" dur="1.6s" repeatCount="indefinite"/>
  </circle>

  <circle cx="120" cy="145" r="8" fill="#FF6500">
    <animate attributeName="cy" values="145;113;145" dur="2.4s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0;0.7;0" dur="2.4s" repeatCount="indefinite"/>
    <animate attributeName="r" values="8;3;8" dur="2.4s" repeatCount="indefinite"/>
  </circle>

  <circle cx="111" cy="140" r="3" fill="#FFD580">
    <animate attributeName="cy" values="140;110;140" dur="1.9s" repeatCount="indefinite" begin="0.5s"/>
    <animate attributeName="cx" values="111;108;111" dur="1.9s" repeatCount="indefinite" begin="0.5s"/>
    <animate attributeName="opacity" values="0;1;0" dur="1.9s" repeatCount="indefinite" begin="0.5s"/>
  </circle>

  <circle cx="129" cy="140" r="3" fill="#FFD580">
    <animate attributeName="cy" values="140;108;140" dur="1.7s" repeatCount="indefinite" begin="0.3s"/>
    <animate attributeName="cx" values="129;133;129" dur="1.7s" repeatCount="indefinite" begin="0.3s"/>
    <animate attributeName="opacity" values="0;1;0" dur="1.7s" repeatCount="indefinite" begin="0.3s"/>
  </circle>
</svg>
  ''';
}